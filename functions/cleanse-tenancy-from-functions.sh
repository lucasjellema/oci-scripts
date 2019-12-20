# shell script using OCI CLI to remove Functions specific resources from OCI tenancy
# * TODO remove policies
# * TODO remove group
# * remove Internet Gateway
# * remove VCN
# * remove special Functions Compartment

FN_COMPARTMENT_NAME=functions-compartment
FN_VCN_NAME=fn-vcn
FN_IGW_NAME=internet-gateway-fn
FN_MANAGE_REPOS_POLICY=fn-repos-management
FN_MANAGE_APP_POLICY=fn-app-management

oci() { docker run --rm --mount type=bind,source=$HOME/.oci,target=/root/.oci stephenpearson/oci-cli:latest "$@"; }

ROOT_COMPARTMENT_OCID=$1

# find Function Compartment OCID
# invoke this function with a single argument that contains the name of the compartment you are looking for
get_compartment_id()
{
  COMPARTMENT_NAME_VAR=$1     
  compartments=$(oci iam compartment list  --compartment-id $ROOT_COMPARTMENT_OCID --all)
  local THE_COMPARTMENT_ID=$(echo $compartments | jq -r --arg compartment_name "$COMPARTMENT_NAME_VAR" '.data | map(select(.name == $compartment_name)) | .[0] | .id')
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_COMPARTMENT_ID"
}
echo "get_compartment_id $FN_COMPARTMENT_NAME"
FN_COMPARTMENT_OCID=$(get_compartment_id $FN_COMPARTMENT_NAME)


# find Policy OCID
# invoke this function with two arguments:
# 1. name of policy
# 2. compartment ocid to find policy in
get_policy_id()
{
  POLICY_NAME_VAR=$1
  COMPARTMENT_OCID_VAR=$2     

  policies=$(oci iam policy list  --compartment-id $COMPARTMENT_OCID_VAR --all)
  local THE_POLICY_ID=$(echo $policies | jq -r --arg policy_name "$POLICY_NAME_VAR" '.data | map(select(.name == $policy_name)) | .[0] | .id')
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_POLICY_ID"
}
# remove policy $FN_MANAGE_REPOS_POLICY
echo "Removing policy $FN_MANAGE_REPOS_POLICY"
echo "get_policy_id $FN_MANAGE_REPOS_POLICY $ROOT_COMPARTMENT_OCID"
FN_POLICY_OCID=$(get_policy_id $FN_MANAGE_REPOS_POLICY $ROOT_COMPARTMENT_OCID)
echo "Found policy $FN_POLICY_OCID"
oci iam policy delete  --policy-id $FN_POLICY_OCID --force

# remove policy $FN_MANAGE_APP_POLICY
echo "Removing policy $FN_MANAGE_APP_POLICY"
echo "get_policy_id $FN_MANAGE_APP_POLICY $FN_COMPARTMENT_OCID"
FN_POLICY_OCID=$(get_policy_id $FN_MANAGE_APP_POLICY $FN_COMPARTMENT_OCID)
echo "Found policy $FN_POLICY_OCID"
oci iam policy delete  --policy-id $FN_POLICY_OCID --force


# find VCN OCID

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
echo "get_vcn_id $FN_VCN_NAME $FN_COMPARTMENT_OCID"
FN_VCN_OCID=`get_vcn_id $FN_VCN_NAME $FN_COMPARTMENT_OCID`   

# find IGW OCID

# invoke this function with two arguments; the first contains the name of the vcn you are looking for, the second the compartment id for the compartment to be searched
get_igw_id()
{
  IGW_DISPLAY_NAME_VAR=$1     
  FN_VCN_OCID_VAR=$2     
  FN_COMPARTMENT_OCID_VAR=$3     
  igws=$(oci network internet-gateway list  --compartment-id $FN_COMPARTMENT_OCID_VAR --vcn-id $FN_VCN_OCID_VAR --all)
  local THE_IGW_ID=$(echo $igws | jq -r --arg display_name "$IGW_DISPLAY_NAME_VAR" '.data | map(select(."display-name" == $display_name)) | .[0] | .id')
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_IGW_ID"
}

echo "get_igw_id $FN_IGW_NAME $FN_VCN_OCID $FN_COMPARTMENT_OCID"
FN_IGW_OCID=`get_igw_id $FN_IGW_NAME $FN_VCN_OCID $FN_COMPARTMENT_OCID`   


# remove IGW
echo "Removing internet gateway $FN_IGW_OCID"
oci network internet-gateway delete  --ig-id $FN_IGW_OCID --force


# remove VCN
echo "Removing $FN_VCN_NAME $FN_VCN_OCID"
oci network vcn delete --vcn-id $FN_VCN_OCID --force


# remove compartment
echo "Removing functions-compartment $FN_COMPARTMENT_OCID"
#oci iam compartment delete --compartment-id $FN_COMPARTMENT_OCID  --force
