#!/bin/bash

#export WSO2_CLIENT_ID=akJoxqsnItyFQ8FeYhOENCzJzS0a
#export WSO2_CLIENT_SECRET=it6_Tnw0r8c9hkhXZYE5MTffNtca
export WSO2_CLIENT_ID=mymvyVrADf8xlNoZFphVjioHffAa
export WSO2_CLIENT_SECRET=9pxnyDjNfcndbb7jD27uDOonxFoa


export WSO2_ADMIN_USERNAME=admin
export WSO2_ADMIN_PASSWORD=admin


#export WSO2_BASE_URL_TOKEN=https://uat-mgt.thailife.com:8243
#export WSO2_BASE_URL_API=https://uat-mgt.thailife.com:9443


export WSO2_BASE_URL_TOKEN=https://localhost:8243
export WSO2_BASE_URL_API=https://localhost:9443





alert() {
  echo ""
  echo " ______________________
 < $* >
 ----------------------
        \   ^__^
         \  (..),7\_______
            (__)\       )\/
                ||----w |
                ||     ||"
  echo ""
}

error() {
  echo ""
  echo " ______________________
  < $* >
 ----------------------
        \   ^__^
         \  (xx)\_______
            (__)\       )\/
             U  ||----w |
                ||     ||" 1>&2

  echo ""
  exit 1
}


basic_token() {
	echo -n ${WSO2_CLIENT_ID}:${WSO2_CLIENT_SECRET} | base64
}

basic_token1() {
	echo -n ${WSO2_CLIENT_ID}:${WSO2_CLIENT_SECRET} | base64
}


admin_token() {
	result=$(curl -s -k -d "grant_type=password&username=${WSO2_ADMIN_USERNAME}&password=${WSO2_ADMIN_PASSWORD}&scope=apim:api_view apim:api_create apim:subscribe apim:api_publish" -H "Authorization: Basic $(basic_token)" ${WSO2_BASE_URL_TOKEN}/token)

	echo "$result" | grep "error" > /dev/null && { echo "$result"; error "Error while get token"; }
	echo "$result" | jq '.access_token' -r
}

get_all_apis() {
	result=$(curl -s -k -H "Authorization: Bearer $(admin_token)" -X GET ${WSO2_BASE_URL_API}/api/am/publisher/v0.14/apis?limit=1000)
	echo "$result"
    
	echo "$result" | jq -rc '.list[]' || { echo "$result"; error "Error while get all apis"; }
}

get_api_detail() {
	api_id="$1"
	
	test -z "${api_id}" && error "Missing parameter api_id"
	
	curl -s -k -H "Authorization: Bearer $(admin_token)" ${WSO2_BASE_URL_API}/api/am/publisher/v0.14/apis/${api_id} | jq .
}





to_json_list() {
	v="$1"
	
	part=$(echo "$v" | sed 's/ /","/g')
	echo "[\"${part}\"]"

}

get_all_applications() {
	result=$(curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X GET -d "$data" ${WSO2_BASE_URL_API}/api/am/store/v0.14/applications)
	
	echo "$result" | jq "[(.list[] | {applicationId: .applicationId, name: .name})]" -r || { echo "$result"; error "Error while get subscribed application"; }
}
export APPLICATIONS_MAP=$(get_all_applications)

export_apis() {
	out_dir="$1"
	
	test -z "${out_dir}" && error "Missing parameter out_dir"
	
	mkdir -p "${out_dir}"
	
	echo "Start extracing apis from ${WSO2_BASE_URL_API} to output dir ${out_dir}"
	
#add 1 declare the variable and export to header of .csv here 
	echo "id,name,description,context,version,provider,status,production_endpoint,enable_CORS,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,isDefaultVersion,intial_Duration,maxDuration,Timeout_Duration" > "${out_dir}/apis.csv"
	get_all_apis | while IFS='' read api; do		
		id=$(echo "$api" | jq .id -r)
		name=$(echo "$api" | jq .name -r)
		description=$(echo "$api" | jq .description -r)
		context=$(echo "$api" | jq .context -r)
		version=$(echo "$api" | jq .version -r)
		provider=$(echo "$api" | jq .provider -r)
		status=$(echo "$api" | jq .status -r)
		
		echo "exporting api $name ..."
		
		if [ -z "$id" ]; then
			echo "WARNING: skip due to missing id"
			echo "$id,$name,$description,$context,$version,$provider,$status,$production_endpoint,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name"
		else
			detail=$(get_api_detail $id)
		
			apiDefinition=$(echo "$detail" | jq .apiDefinition -r)
			
			authType=$(echo "$apiDefinition" | jq '.paths[] | .get | ."x-auth-type"' -r)
			
			endpointConfig=$(echo "$detail" | jq .endpointConfig -r)
			
			production_endpoint=$(echo "$endpointConfig" | jq ".production_endpoints | .url" -r)

#add 2 assign value here
			#corsConfigurationEnabled
			tftest=$(echo "$detail" | grep corsConfigurationEnabled | grep true )
			if [ -z "$tftest" ]; then
				enable_CORS="false"
                   	else 
				enable_CORS="true"	
			fi			

			accessControlAllowHeaders=$(echo "$detail" | jq '.corsConfiguration | .accessControlAllowHeaders | join(" ")' -cr)
			accessControlAllowMethods=$(echo "$detail" | jq '.corsConfiguration | .accessControlAllowMethods | join(" ")' -cr)
			
			application_name=$(get_subscribed_applications "$id")

			#isDefaultVersion
			tftest=$(echo "$detail" | grep isDefaultVersion | grep true )
			if [ -z "$tftest" ]; then
				isDefaultVersion="false"
                   	else 
				isDefaultVersion="true"	
			fi			

			#intial_Duration
			intial_Duration=$(echo "$detail" | grep suspendDuration | sed 's/"//g' | sed 's/[\]//g' | sed 's/.*suspendDuration://' | sed 's/,.*//')
			#maxDuration
			maxDuration=$(echo "$detail" | grep suspendMaxDuration | sed 's/"//g' | sed 's/[\]//g' | sed 's/.*suspendMaxDuration://' | sed 's/,.*//')
			#Timeout_Duration
			Timeout_Duration=$(echo "$detail" | grep actionDuration | sed 's/"//g' | sed 's/[\]//g' | sed 's/.*actionDuration://' | sed 's/,.*//' | sed 's/}//g' | sed 's/n//g')

#add 3 echo all value to .csv file here
			echo "$id,$name,$description,$context,$version,$provider,$status,$production_endpoint,$enable_CORS,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$isDefaultVersion,$intial_Duration,$maxDuration,$Timeout_Duration" >> "${out_dir}/apis.csv"
		fi
	done
}


#############################################
# -  - - update_apis() - - - - 
#############################################
update_apis() {
	in_dir="$1"
	
	test -z "${in_dir}" && error "Missing parameter in_dir"
	
	
	echo "id,name,description,context,version,provider,status,production_endpoint,enable_CORS,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,isDefaultVersion,intial_Duration,maxDuration,Timeout_Duration,status,status_description" > "${in_dir}/update_result.csv"

	echo "id,name,description,context,version,provider,status,production_endpoint,enable_CORS,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,isDefaultVersion,intial_Duration,maxDuration,Timeout_Duration" > "${in_dir}/update_id.csv"
	
	###Add 1
	cat "${in_dir}/apis.csv" | while IFS=, read -r id name description context version provider status production_endpoint enable_CORS accessControlAllowHeaders accessControlAllowMethods authType application_name isDefaultVersion intial_Duration maxDuration Timeout_Duration
	do
		test "$name" == "name" && continue # skip header

		idcheck=$id
		
		version=$(echo $version | sed 's/"//g') # strip quotes
		authType=$(echo "$authType" | tr -d '\r') # strip windows newline
		application_name=$(echo "$application_name" | tr -d '\r') # strip windows newline
   	###Add 2
		raw_line="$name,$description,$context,$version,$provider,$status,$production_endpoint,$enable_CORS,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$isDefaultVersion,$intial_Duration,$maxDuration,$Timeout_Duration"
		
		accessControlAllowHeaders=$(to_json_list "$accessControlAllowHeaders")
		accessControlAllowMethods=$(to_json_list "$accessControlAllowMethods")
		
		apiDefinition_template=$(cat resources/apiDefinition_template.json | awk '{print}' ORS=' ')
		apiDefinition=$(echo "$apiDefinition_template" | jq ".paths[].get.\"x-auth-type\"=\"${authType}\" | .paths[].post.\"x-auth-type\"=\"${authType}\" | .info.title=\"${name}\" | .info.version=\"${version}\"")
		apiDefinition=$(jq -Rs . <<< "$apiDefinition")



		endpointConfig_template=$(cat resources/endpointConfig_template.json | awk '{print}' ORS=' ')
		endpointConfig=$(echo "$endpointConfig_template" | jq ".production_endpoints.url=\"${production_endpoint}\" |.production_endpoints.config.suspendDuration=\"${intial_Duration}\" |.production_endpoints.config.suspendMaxDuration=\"${maxDuration}\"
|.production_endpoints.config.actionDuration=\"${Timeout_Duration}\" 
")
		endpointConfig=$(jq -Rs . <<< "$endpointConfig")



		
		api_detail_template=$(cat resources/api_detail_template.json | awk '{print}' ORS=' ')
		api_detail=$(echo "$api_detail_template" | jq ".apiDefinition=${apiDefinition} | .endpointConfig=${endpointConfig} | .id=\"${id}\" | .name=\"${name}\" | .description=\"${description}\" | .context=\"${context}\" | .version=\"${version}\" | .provider=\"${provider}\" | .status=\"${status}\" |.isDefaultVersion=\"${isDefaultVersion}\" | .corsConfiguration.corsConfigurationEnabled=${enable_CORS} | .corsConfiguration.accessControlAllowHeaders=${accessControlAllowHeaders} | .corsConfiguration.accessControlAllowMethods=${accessControlAllowMethods}")
		
		
		if [ -z "$id" ]; then
			echo ""
			echo "CREATE: $name ..."
			result=$(curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X POST -d "$api_detail" ${WSO2_BASE_URL_API}/api/am/publisher/v0.14/apis/${id})
			
			echo "$result" | grep "production_endpoints" > /dev/null && action_status=CREATE_SUCCESS || action_status=ERROR
			echo "$result"
			
			if [ "$action_status" == "ERROR" ]; then
				error_description=$(echo "$result" | jq '.description' -r)
			else
				error_description=null
			fi
			
			
			id=$(echo "$result" |  jq .id -r)
			echo "$id,$raw_line,$action_status,$error_description" >> "${in_dir}/update_result.csv"
                        echo "$id,$raw_line" >> "${in_dir}/update_id.csv"
		else
			echo ""
			echo "UPDATE: $name ..."
			result=$(curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X PUT -d "$api_detail" ${WSO2_BASE_URL_API}/api/am/publisher/v0.14/apis/${id})
			
			echo "$result" | grep "production_endpoints" > /dev/null && action_status=UPDATE_SUCCESS || action_status=ERROR
			echo "$result"
			
			if [ "$action_status" == "ERROR" ]; then
				error_description=$(echo "$result" | jq '.description' -r)
			else
				error_description=null
			fi
			echo "$id,$raw_line,$action_status,$error_description" >> "${in_dir}/update_result.csv"
			echo "$id,$raw_line" >> "${in_dir}/update_id.csv"
		fi
	done
		
#cp ${in_dir}/update_id.csv apiupdate/apis.csv
cp ${in_dir}/update_id.csv apipublish/apis.csv
cp ${in_dir}/update_id.csv apisubscribe/apis.csv
cp ${in_dir}/update_id.csv apiunsubscribe/apis.csv
cp ${in_dir}/update_id.csv apiremove/apis.csv
rm ${in_dir}/update_id.csv    
}
######end update_apis######





publish_apis() {
	in_dir="$1"
	
	test -z "${in_dir}" && error "Missing parameter in_dir"
	
	
	echo "id,name,description,context,version,provider,status,production_endpoint,enable_CORS,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,isDefaultVersion,intial_Duration,maxDuration,Timeout_Duration,status,status_description" > "${in_dir}/publish_result.csv"
	
	cat "${in_dir}/apis.csv" | while IFS=, read -r id name description context version provider status production_endpoint enable_CORS accessControlAllowHeaders accessControlAllowMethods authType application_name isDefaultVersion intial_Duration maxDuration Timeout_Duration
	do
		test "$name" == "name" && continue # skip header
		
		version=$(echo $version | sed 's/"//g') # strip quotes
		authType=$(echo "$authType" | tr -d '\r') # strip windows newline
		application_name=$(echo "$application_name" | tr -d '\r') # strip windows newline
		
		echo ""
		echo "PUBLISH: $name ..."
		result=$(change_status_api "$id" "Publish")
		
		if [ -z "$result" ]; then
			action_status=PUBLISH_SUCCESS
			error_description=null
		else
			action_status=ERROR
			error_description=$(echo "$result" | jq '.description' -r)
			echo "$result"
		fi
		
		echo "$id,$name,$description,$context,$version,$provider,PUBLISHED,$production_endpoint,$enable_CORS,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$isDefaultVersion,$intial_Duration,$maxDuration,$Timeout_Duration,$action_status,$error_description" >> "${in_dir}/publish_result.csv"
		
	done
}



subscribe_apis() {
	in_dir="$1"
	
	test -z "${in_dir}" && error "Missing parameter in_dir"
	
	
	echo "id,name,description,context,version,provider,status,production_endpoint,enable_CORS,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,isDefaultVersion,intial_Durationm,maxDuration,Timeout_Duration,status,status_description" > "${in_dir}/subscribe_result.csv"
	
	cat "${in_dir}/apis.csv" | while IFS=, read -r id name description context version provider status production_endpoint enable_CORS accessControlAllowHeaders accessControlAllowMethods authType application_name isDefaultVersion intial_Duration maxDuration Timeout_Duration
	do
		test "$name" == "name" && continue # skip header
		
		version=$(echo $version | sed 's/"//g') # strip quotes
		authType=$(echo "$authType" | tr -d '\r') # strip windows newline
		application_name=$(echo "$application_name" | tr -d '\r') # strip windows newline
		
		echo ""
		echo "SUBSCRIBE: $name for $application_name ..."
		
		app_id_list=$(transform_application_name_to_id $application_name)
		
		if [ -z "$app_id_list" ]; then
			action_status=ERROR
			error_description="No Application"
			echo "$id,$name,$description,$context,$version,$provider,$status,$production_endpoint,$enable_CORS,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$isDefaultVersion,$intial_Duration,$maxDuration,$Timeout_Duration,$action_status,$error_description" >> "${in_dir}/subscribe_result.csv"
			continue
		fi
		
		for app_id in $app_id_list
		do
			result=$(subscribe_api "$id" "$app_id" "Unlimited")
			if [ ! -z "$result" ]; then
				error_description=$(echo "$result" | jq '.description' -r)
				echo "$error_description" | grep "Specified subscription already exists" > /dev/null \
					&& { result=""; echo "Subscription already exists for $(transform_application_id_to_name $app_id)"; } \
					|| break
			fi
		done
		
		checkUNBLOCKED=$(echo $result | grep "UNBLOCKED")

		if [ -z "$checkUNBLOCKED" ]; then
			action_status=ERROR
			error_description=$(echo "$result" | jq '.description' -r)
			echo "$result"
		else

			action_status=SUBSCRIBE_SUCCESS
			error_description=$(echo "$result" | jq '.description' -r)
		fi
		
		echo "$id,$name,$description,$context,$version,$provider,$status,$production_endpoint,$enable_CORS,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$isDefaultVersion,$intial_Duration,$maxDuration,$Timeout_Duration,$action_status,$error_description" >> "${in_dir}/subscribe_result.csv"
		
	done
}

unsubscribe_apis() {
	in_dir="$1"
	
	test -z "${in_dir}" && error "Missing parameter in_dir"
	
	
	echo "id,name,description,context,version,provider,status,production_endpoint,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,status,status_description" > "${in_dir}/unsubscribe_result.csv"
	
	cat "${in_dir}/apis.csv" | while IFS=, read -r id name description context version provider status production_endpoint accessControlAllowHeaders accessControlAllowMethods authType application_name
	do
		test "$name" == "name" && continue # skip header
		
		version=$(echo $version | sed 's/"//g') # strip quotes
		authType=$(echo "$authType" | tr -d '\r') # strip windows newline
		application_name=$(echo "$application_name" | tr -d '\r') # strip windows newline
		
		echo ""
		echo "UNSUBSCRIBE: $name ..."
		
		result=$(unsubscribe_api "$id")
		
		if [ -z "$result" ]; then
			action_status=UNSUBSCRIBE_SUCCESS
			error_description=null
		else
			action_status=ERROR
			error_description=$(echo "$result" | jq '.description' -r)
			echo "$result"
		fi
		
		echo "$id,$name,$description,$context,$version,$provider,$status,$production_endpoint,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$action_status,$error_description" >> "${in_dir}/unsubscribe_result.csv"
		
	done
}

remove_apis() {
	in_dir="$1"
	
	test -z "${in_dir}" && error "Missing parameter in_dir"
	
	
	echo "id,name,description,context,version,provider,status,production_endpoint,accessControlAllowHeaders,accessControlAllowMethods,authType,application_name,status,status_description" > "${in_dir}/remove_result.csv"
	
	cat "${in_dir}/apis.csv" | while IFS=, read -r id name description context version provider status production_endpoint accessControlAllowHeaders accessControlAllowMethods authType application_name
	do
		test "$name" == "name" && continue # skip header
		
		version=$(echo $version | sed 's/"//g') # strip quotes
		authType=$(echo "$authType" | tr -d '\r') # strip windows newline
		application_name=$(echo "$application_name" | tr -d '\r') # strip windows newline
		
		echo ""
		echo "REMOVE: $name ..."
		
		result=$(remove_api "$id")
		
		if [ -z "$result" ]; then
			action_status=REMOVE_SUCCESS
			error_description=null
		else
			action_status=ERROR
			error_description=$(echo "$result" | jq '.description' -r)
			echo "$result"
		fi
		
		echo "$id,$name,$description,$context,$version,$provider,$status,$production_endpoint,$accessControlAllowHeaders,$accessControlAllowMethods,$authType,$application_name,$action_status,$error_description" >> "${in_dir}/remove_result.csv"
		
	done
}


change_status_api() {
	api_id=$1
	status=$2
	
	test -z "$api_id" && error "Missing api_id"
	test -z "$status" && error "Missing status"
	
	curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X POST "${WSO2_BASE_URL_API}/api/am/publisher/v0.14/apis/change-lifecycle?apiId=$api_id&action=$status"
}

subscribe_api() {
	api_id=$1
	application_id=$2
	tier=$3
	
	test -z "$api_id" && error "Missing api_id"
	test -z "$application_id" && error "Missing application_id"
	test -z "$tier" && error "Missing tier"

	subscription_template=$(cat resources/subscription_template.json | awk '{print}' ORS=' ')
	data=$(echo "$subscription_template" | jq ".tier=\"${tier}\" | .apiIdentifier=\"${api_id}\" | .applicationId=\"${application_id}\"")
	curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X POST -d "$data" ${WSO2_BASE_URL_API}/api/am/store/v0.14/subscriptions
}

unsubscribe_api() {
	api_id=$1
	
	test -z "$api_id" && error "Missing api_id"
	
	get_all_api_subscription $api_id | jq '.list[] | .subscriptionId' -r | while read subscriptionId
	do
		sub_id=$(echo $subscriptionId)
		curl -s -k -H "Authorization: Bearer $(admin_token)" -X DELETE "${WSO2_BASE_URL_API}/api/am/store/v0.14/subscriptions/${sub_id}"
	done	
}

remove_api() {
	api_id=$1
	
	test -z "$api_id" && error "Missing api_id"
	
	curl -s -k -H "Authorization: Bearer $(admin_token)" -X DELETE "${WSO2_BASE_URL_API}/api/am/publisher/4/apis/${api_id}"
}

get_all_api_subscription() {
	api_id=$1
	
	test -z "$api_id" && error "Missing api_id"
	
	curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" "${WSO2_BASE_URL_API}/api/am/store/v0.14/subscriptions?apiId=${api_id}"
}

get_application_id_by_name() {
	application_name=$1

	curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X GET -d "$data" ${WSO2_BASE_URL_API}/api/am/store/v0.14/applications | jq ".list[] | select(.name == \"${application_name}\") | .applicationId" -r
}

transform_application_id_to_name() {
	app_id_list=$*
	
	for app_id in $app_id_list
	do
		printf "%s " $(echo "$APPLICATIONS_MAP" | jq -r ".[] | select(.applicationId == \"$app_id\") | .name")
	done
	echo ""
}

transform_application_name_to_id() {
	app_name_list=$*
	
	for app_name in $app_name_list
	do
		printf "%s " $(echo "$APPLICATIONS_MAP" | jq -r ".[] | select(.name == \"$app_name\") | .applicationId")
	done
	echo ""
}

get_subscribed_applications() {
	api_id=$1
	
	test -z "$api_id" && error "Missing api_id"
	
	result=$(curl -s -k -H "Authorization: Bearer $(admin_token)" -H "Content-Type: application/json" -X GET "${WSO2_BASE_URL_API}/api/am/store/v0.14/subscriptions?apiId=${api_id}")
	
	app_id_list=$(echo "$result" | jq -r '[(.list[] | .applicationId)] | join(" ")') || { echo "$result"; error "Error while get subscribed application"; }
	
	transform_application_id_to_name $app_id_list
}

# admin_token
# get_application_id_by_name DefaultApplication

# subscribe_api "f9c75d7a-4eae-4411-80ae-e862e1cfd81c" "DefaultApplication" "Unlimited"
# change_status_api "f9c75d7a-4eae-4411-80ae-e862e1cfd81c" aaa
# get_subscribed_applications f9c75d7a-4eae-4411-80ae-e862e1cfd81c
# transform_application_name_to_id $(get_subscribed_applications 079643c8-a708-4cfa-86c5-6e2e116e592d)
# get_all_applications
# transform_application_id_to_name 362eb74d-aedb-449b-8409-713e1051bd46 362eb74d-aedb-449b-8409-713e1051bd46 362eb74d-aedb-449b-8409-713e1051bd46 362eb74d-aedb-449b-8409-713e1051bd46
# get_all_api_subscription 852bf444-5311-4664-97bb-a4a06a1acb21 | jq '.list[] | .subscriptionId' -r
# unsubscribe_api 852bf444-5311-4664-97bb-a4a06a1acb21
# exit 0;

# export_apis ./sit
# update_apis ./sit	

test ${#} -lt 1 && error "Missing method. Valid methods are export_apis, update_apis"

test -z "$WSO2_CLIENT_ID" && error "Missing environment variable WSO2_CLIENT_ID"
test -z "$WSO2_CLIENT_SECRET" && error "Missing environment variable WSO2_CLIENT_SECRET"
test -z "$WSO2_ADMIN_USERNAME" && error "Missing environment variable WSO2_ADMIN_USERNAME"
test -z "$WSO2_ADMIN_PASSWORD" && error "Missing environment variable WSO2_ADMIN_PASSWORD"
test -z "$WSO2_BASE_URL_TOKEN" && error "Missing environment variable WSO2_BASE_URL_TOKEN"
test -z "$WSO2_BASE_URL_API" && error "Missing environment variable WSO2_BASE_URL_API"

case "$1" in
	"api_detail")
		shift
                get_api_detail $*
		;;

	"export_apis") 
		shift
		export_apis $*
		;;
	"update_apis")
		shift
		update_apis $*
		;;
	"publish_apis")
		shift
		publish_apis $*
		;;
	"subscribe_apis")
		shift
		subscribe_apis $*
		;;
	"unsubscribe_apis")
		shift
		unsubscribe_apis $*
		;;
	"remove_apis")
		shift
		remove_apis $*
		;;	
	*)
		usage
		error "Unknown method: $1"
		;;
esac

