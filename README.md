# oci-scripts
Scripts for creating, inspecting and removing OCI resources - using Oracle Cloud Infrastructure CLI

This repository provides scripts that work against Oracle Cloud Infrastructure through CLI, SDK, API or other means - in order to create, update, inspect and remove OCI resources.

One easy way to run these scripts is the following setup:

1. Use a Linux Host with Docker installed
2. Prepare directory for OCI config files 
3. Run OCI CLI Docker container image; a command dialog is started; provide tenancy and user OCID as well as region; a configuration file is written in the directory on the host as well as a generated key-pair 
4. Add the public key to the OCI account for the user)
5. Create shortcut command for OCI CLI on Docker host

Also see instructions in this article:  https://technology.amis.nl/2018/10/14/get-going-quickly-with-command-line-interface-for-oracle-cloud-infrastructure-using-docker-container/.
