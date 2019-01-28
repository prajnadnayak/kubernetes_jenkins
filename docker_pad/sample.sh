#!/bin/sh

make_snapshots()
{

# Get all namespaces
namespaces=`kubectl get namespaces -o json | jq --raw-output '.items[].metadata.name'`


# Reads the configurable values. This is avoid any hardcoding and create flexibility in maintaining env specific variables

local snapShotResourceGroupSuffix=`echo $(jq --raw-output '.snapShotResourceGroupSuffix' config.json)`

local snapShotNameSuffix=`echo $(jq --raw-output '.snapShotNameSuffix' config.json)`

local ignorableNamespaces=`echo $(jq --raw-output '.ignorableNamespaces' config.json)`

local azureProvidedPVCPrefix=`echo $(jq --raw-output '.azureProvidedPVCPrefix' config.json)`


echo $azureProvidedPVCPrefix


# Iterate through all the namespaces and for each namespace(except default|kube-public|kube-system|monitoring)

# take a snapshot of the persisten volume(PV) available. Ideally each of these namespace should not have more
# than one PV because each namespace is intended for only one Jenkins instance

for ns in "${namespaces[@]}"
do
  if [ "$ns" =~ ^$ignorableNamespaces$ ] 
   then
    echo "#Do nothing "
  else
  
  # Get PVC from the namespace in the current loop
 
   pvcName=`kubectl get pvc --namespace "$ns" -o json | jq --raw-output '.items[].spec.volumeName'`
  
  pvcName=$azureProvidedPVCPrefix-$pvcName
   
 echo $pvcName
   
 pvcId=`az disk list -o json | jq --raw-output '.[] | select(.name=="'"$pvcName"'") | .id'`
  
  echo ----------------------------------
  
  # Form the azure resourceGroup name following the naming format $nameOfTheK8sNamepsace--jenkins-snapshot
  
  resourceGroup="$ns"-"$snapShotResourceGroupSuffix"

   
 #This command creates a new one if none is found with the same name.
    
createResourceGrousp=`az group create -l westeurope -n "$resourceGroup"`

  
  # Form the name given to the snapshot with the resourceGroup name as the prefix and 'date_timestamp(HH:MM:SS)' as suffix'
  
  snapShotName="$resourceGroup"-`date +"$snapShotNameSuffix"`

    
#Creation of the snapshot
  
  echo "Commencing the snapshot named $snapShotName under the resource group $resourceGroup"
 
   snapShot=`az snapshot create --resource-group "$resourceGroup" --name "$snapShotName" --source "$pvcId" &`
  
  echo "Snapshot named $snapShotName under the resource group $resourceGroup succeefully created!"

    echo ----------------------------------
  fi
done 
}
make_snapshots

