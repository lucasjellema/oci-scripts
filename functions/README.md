These scripts help you getting started (or finished) with Oracle Functions on OCI - by preparing the OCI tenancy with the required resources.

prepare-tenancy-for-functions.sh performs the following steps (using the root compartment id as input):
* create compartment *functions-compartment* to hold all functions related resources
* create VCN fn-vcn


Start this script with:
`./prepare-tenancy-for-functions.sh ocid1.tenancy.oc1..aaaaaaa...` 