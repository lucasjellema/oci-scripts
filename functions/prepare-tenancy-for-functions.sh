# shell script using OCI CLI to prepare OCI tenancy for Functions
# see docs: 
# https://docs.cloud.oracle.com/iaas/Content/Functions/Tasks/functionsconfiguringtenancies.htm
# https://docs.cloud.oracle.com/iaas/Content/Functions/Tasks/functionscreatingpolicies.htm

FN_COMPARTMENT_NAME=functions-compartment
FN_DEVS_GROUP=FN_DEVELOPERS
FN_VCN_NAME=VCN-FN
FN_SUBNET_NAME='Public Subnet-VCN-FN'
FN_IGW_NAME=internet-gateway-fn
FN_MANAGE_REPOS_POLICY=fn-repos-management
FN_MANAGE_APP_POLICY=fn-app-management
FN_GROUP_USE_VCN_POLICY=fn-group-use-network-family
FN_FAAS_USE_VCN_POLICY=fn-faas-use-network-family
FN_FAAS_READ_REPOS_POLICY=fn-faas-read-repos
FN_FUNCTION_APP=lab-app

oci() { docker run --rm --mount type=bind,source=$HOME/.oci,target=/root/.oci stephenpearson/oci-cli:latest "$@"; }
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True

ROOT_COMPARTMENT_OCID=$1

# create a dedicated compartment for Functions
CREATE_FN_COMP="false"
if [ $CREATE_FN_COMP = "true" ]
then
  echo "creating $FN_COMPARTMENT_NAME"
  oci iam compartment create --compartment-id $ROOT_COMPARTMENT_OCID  --name $FN_COMPARTMENT_NAME --description "Compartment for Functions and associated OCI resources"
else
  echo "$FN_COMPARTMENT_NAME NOT created"
fi

# invoke this function with a single argument that contains the name of the compartment you are looking for
get_compartment_id()
{
  COMPARTMENT_NAME_VAR=$1     
  compartments=$(oci iam compartment list  --compartment-id $ROOT_COMPARTMENT_OCID --all)
  local THE_COMPARTMENT_ID=$(echo $compartments | jq -r --arg compartment_name "$COMPARTMENT_NAME_VAR" '.data | map(select(.name == $compartment_name)) | .[0] | .id')
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_COMPARTMENT_ID"
}

FN_COMPARTMENT_OCID=$(get_compartment_id $FN_COMPARTMENT_NAME)
echo "OCID for $FN_COMPARTMENT_NAME= $FN_COMPARTMENT_OCID"

# Create the VCN and Subnets https://docs.cloud.oracle.com/iaas/Content/Functions/Tasks/functionscreatingvcn.htm



# invoke this function with two arguments; the firstcontains the name of the vcn you are looking for, the second the compartment id for the compartment to be searched
get_vcn_id()
{
  VCN_DISPLAY_NAME_VAR=$1     
  FN_COMPARTMENT_OCID_VAR=$2     
  vcns=$(oci network vcn list  --compartment-id $FN_COMPARTMENT_OCID_VAR --all)
  local THE_VCN_ID=$(echo $vcns | jq -r --arg display_name "$1" '.data | map(select(."display-name" == $display_name)) | .[0] | .id')
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_VCN_ID"
}


CREATE_VCN="false"
if [ $CREATE_VCN = "true" ]
then
        # create a virtual cloud network
        echo "creating virtual cloud network"
        # https://docs.cloud.oracle.com/iaas/Content/ContEng/Concepts/contengnetworkconfigexample.htm
        oci network vcn create --compartment-id $FN_COMPARTMENT_OCID --cidr-block '10.0.0.0/16'  --display-name $FN_VCN_NAME  --dns-label 'fn' 
        echo "created a new VCN: $FN_VCN"
else  
  echo "skipping VCN creation"
fi
FN_VCN_OCID=`get_vcn_id $FN_VCN_NAME $FN_COMPARTMENT_OCID` 
echo "OCID for $FN_VCN_NAME= $FN_VCN_OCID"

# invoke this function with three arguments; 
# 1. name of subnet
# 2. OCID of VCN
# 3. OCID of compartment
get_subnet_id()
{
  SUBNET_DISPLAY_NAME_VAR=$1     
  FN_VCN_OCID_VAR=$2
  FN_COMPARTMENT_OCID_VAR=$3     
  vcns=$(oci network subnet list  --compartment-id $FN_COMPARTMENT_OCID_VAR --vcn-id $FN_VCN_OCID_VAR --all)
  local THE_SUBNET_ID=$(echo $vcns | jq -r --arg display_name "$1" '.data | map(select(."display-name" == $display_name)) | .[0] | .id')
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_SUBNET_ID"
}




CREATE_SUBNET="false"
if [ $CREATE_SUBNET = "true" ]
then
        # create a virtual cloud network
        echo "creating subnet"
        oci network subnet create --compartment-id $FN_COMPARTMENT_OCID --vcn-id $FN_VCN_OCID --cidr-block '10.0.0.0/24'  --display-name $FN_SUBNET_NAME  --dns-label fn-subnet 
else  
  echo "skipping VCN creation"
fi
FN_SUBNET_OCID=`get_subnet_id $FN_SUBNET_NAME $FN_VCN_OCID $FN_COMPARTMENT_OCID` 
echo "OCID for $FN_SUBNET_NAME= $FN_SUBNET_OCID"

CREATE_IGW="false"
if [ $CREATE_IGW = "true" ]
then
  echo "creating Internet Gateway in the VCN"
  oci network internet-gateway create --compartment-id $FN_COMPARTMENT_OCID --vcn-id $FN_VCN_OCID  --is-enabled true  --display-name $FN_IGW_NAME
else
  echo "skipping creation of Internet Gateway"
fi

# create group FN_DEVELOPERS
CREATE_GROUP="true"
if [ $CREATE_GROUP = "true" ]
then
  oci iam group create --name $FN_DEVS_GROUP --compartment-id $ROOT_COMPARTMENT_OCID  --description "Group for users who develop Function resources"
else
  echo "Skipping Group creation"
fi

# Creating required policies
oci iam policy create  --name $FN_MANAGE_REPOS_POLICY --compartment-id $ROOT_COMPARTMENT_OCID  --statements "[ \"Allow group $FN_DEVS_GROUP to manage repos in tenancy\"]"  --description "policy for granting rights to $FN_DEVS_GROUP to manage Repos in tenancy"

oci iam policy create  --name $FN_MANAGE_APP_POLICY --compartment-id $FN_COMPARTMENT_OCID  --statements "[ \"Allow group $FN_DEVS_GROUP to manage functions-family in compartment functions-compartment\",
\"Allow group $FN_DEVS_GROUP to read metrics in compartment functions-compartment\"]" --description "policy for granting rights to $FN_DEVS_GROUP to manage Function Apps in compartment $FN_COMPARTMENT_NAME"

echo creating policy $FN_GROUP_USE_VCN_POLICY
oci iam policy create  --name $FN_GROUP_USE_VCN_POLICY --compartment-id $FN_COMPARTMENT_OCID  --statements "[ \"Allow group $FN_DEVS_GROUP to use virtual-network-family in compartment $FN_COMPARTMENT_NAME\"]"  --description "Create a Policy to Give Oracle Functions Users Access to Network Resources in compartment $FN_COMPARTMENT_NAME"
echo creating policy $FN_FAAS_USE_VCN_POLICY
oci iam policy create  --name $FN_FAAS_USE_VCN_POLICY --compartment-id $ROOT_COMPARTMENT_OCID  --statements "[ \"Allow service FaaS to use virtual-network-family in compartment $FN_COMPARTMENT_NAME\"]"  --description "Create a Policy to Give the Oracle Functions Service Access to Network Resources"
echo creating policy $FN_FAAS_READ_REPOS_POLICY
oci iam policy create  --name $FN_FAAS_READ_REPOS_POLICY --compartment-id $ROOT_COMPARTMENT_OCID  --statements "[ \"Allow service FaaS to read repos in tenancy\"]"  --description "Create a Policy to Give the Oracle Functions Service Access to Repositories in Oracle Cloud Infrastructure Registry"

# creating Function App
oci fn application create --display-name $FN_FUNCTION_APP --compartment-id $FN_COMPARTMENT_OCID --subnet-ids "[\"$FN_SUBNET_OCID\"]"