# shell script using OCI CLI to prepare OCI tenancy for Functions

oci() { docker run --rm --mount type=bind,source=$HOME/.oci,target=/root/.oci stephenpearson/oci-cli:latest "$@"; }

ROOT_COMPARTMENT_OCID=$1

# create a dedicated compartment for Functions
CREATE_FN_COMP="false"
if [ $CREATE_FN_COMP = "true" ]
then
  echo "creating functions-compartment"
  oci iam compartment create --compartment-id $ROOT_COMPARTMENT_OCID  --name functions-compartment --description "Compartment for Functions and associated OCI resources"
else
  echo "functions-compartment NOT created"
fi

# invoke this function with a single argument that contains the name of the compartment you are looking for
get_compartment_id()
{
  compartments=$(oci iam compartment list  --compartment-id $ROOT_COMPARTMENT_OCID --all)
  local THE_COMPARTMENT_ID=`echo $compartments | jq -r --arg compartment_name "$1" '.data | map(select(.name == $compartment_name)) | .[0] | .id'`
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_COMPARTMENT_ID"
}

FN_COMPARTMENT_OCID=`get_compartment_id "functions-compartment"`
echo "OCID for functions-compartment= $FN_COMPARTMENT_OCID"

# Create the VCN and Subnets https://docs.cloud.oracle.com/iaas/Content/Functions/Tasks/functionscreatingvcn.htm



# invoke this function with two arguments; the firstcontains the name of the vcn you are looking for, the second the compartment id for the compartment to be searched
get_vcn_id()
{
  vcns=$(oci network vcn list  --compartment-id $2 --all)
  local THE_VCN_ID=`echo $vcns | jq -r --arg display_name "$1" '.data | map(select(."display-name" == $display_name)) | .[0] | .id'`
  # this line provides the output from this function; this output can be captured in a variable by the caller using VAR=`function param1`  
  echo "$THE_VCN_ID"
}


CREATE_VCN="false"
if [ $CREATE_VCN = "true" ]
then
        # create a virtual cloud network
        echo "creating virtual cloud network"
        # https://docs.cloud.oracle.com/iaas/Content/ContEng/Concepts/contengnetworkconfigexample.htm
        FN_VCN=`oci network vcn create --compartment-id $FN_COMPARTMENT_OCID --cidr-block '172.16.1.0/24'  --display-name 'fn-vcn'  --dns-label 'fn' `
        FN_VCN_OCID=`echo $FN_VCN | jq '.data | .id'`
        echo "created a new VCN with OCI $FN_VCN_ID"
else  
  echo "skipping VCN creation"
  FN_VCN_OCID=`get_vcn_id "fn-vcn" $FN_COMPARTMENT_OCID` 
  echo "OCID for fn-vcn= $FN_VCN_OCID"
fi

        