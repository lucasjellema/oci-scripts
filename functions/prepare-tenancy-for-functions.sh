# shell script using OCI CLI to prepare OCI tenancy for Functions
# see docs: 
# https://docs.cloud.oracle.com/iaas/Content/Functions/Tasks/functionsconfiguringtenancies.htm
# https://docs.cloud.oracle.com/iaas/Content/Functions/Tasks/functionscreatingpolicies.htm

FN_COMPARTMENT_NAME=functions-compartment
FN_DEVS_GROUP=FN_DEVELOPERS
FN_VCN_NAME=fn-vcn
FN_IGW_NAME=internet-gateway-fn
FN_MANAGE_REPOS_POLICY=fn-repos-management
FN_MANAGE_APP_POLICY=fn-app-management
FN_GROUP_USE_VCN_POLICY=fn-group-use-network-family
FN_FAAS_USE_VCN_POLICY=fn-faas-use-network-family
FN_FAAS_READ_REPOS_POLICY=fn-faas-read-repos

oci() { docker run --rm --mount type=bind,source=$HOME/.oci,target=/root/.oci stephenpearson/oci-cli:latest "$@"; }

ROOT_COMPARTMENT_OCID=$1

# create a dedicated compartment for Functions
CREATE_FN_COMP="true"
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


CREATE_VCN="true"
if [ $CREATE_VCN = "true" ]
then
        # create a virtual cloud network
        echo "creating virtual cloud network"
        # https://docs.cloud.oracle.com/iaas/Content/ContEng/Concepts/contengnetworkconfigexample.htm
        oci network vcn create --compartment-id $FN_COMPARTMENT_OCID --cidr-block '172.16.1.0/24'  --display-name $FN_VCN_NAME  --dns-label 'fn' 
        echo "created a new VCN: $FN_VCN"
else  
  echo "skipping VCN creation"
fi
FN_VCN_OCID=`get_vcn_id $FN_VCN_NAME $FN_COMPARTMENT_OCID` 
echo "OCID for $FN_VCN_NAME= $FN_VCN_OCID"


CREATE_IGW="true"
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

