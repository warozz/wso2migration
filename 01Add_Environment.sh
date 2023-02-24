./apimcli/apimcli add-env -n DEV_SGI \
    --registration https://10.102.60.112:9443/client-registration/v0.11/register \
    --apim https://10.102.60.112:9443 \
    --token http://10.102.60.112:8280/token \
    --import-export https://10.102.60.112:9443/api-import-export-2.1.0-v3 \
    --admin https://10.102.60.112:9443/api/am/admin/v0.11 \
    --api_list https://10.102.60.112:9443/api/am/publisher/v0.11/apis \
    --app_list https://10.102.60.112:9443/api/am/store/v0.11/applications


    ./apictl add env DEV_SGI \
    --apim https://10.102.60.112:9443 \
    --token http://10.102.60.112:8280/token \\
    --api_list https://10.102.60.112:9443/api/am/publisher/v0.11/apis \
    --app_list https://10.102.60.112:9443/api/am/store/v0.11/applications


      ./apictl add env POC_SGI \
    --apim https://localhost:9443 \
    --token http://localhost:8280/token \\
    --api_list https://localhost:9443/api/am/publisher/v0.11/apis \
    --app_list https://localhost:9443/api/am/store/v0.11/applications


    
