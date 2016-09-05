<cfcomponent>

	<!---
		Component Handles Elastic Interaction. Methods containing business logic use this component for
		communicating with es.

		Functions
		- isValidHost
		- isRunning
		- getIndexStatus
		- indexData
		- createIndex
		- getIndexContents
		- getScrollData
		- searchIndex
		- reMapIndex
		- updateIndexItem
		- deleteIndex
		- getCurrentIndexes
		- getIndexSettings
		- getIndexMappings
		- getAllDocumentIds
	--->

	<!--- Is Valid Host --->
	<cffunction name="isValidHost" access="private" hint="Returns Boolean if Requested Host is a valid elastic endpoint">
			<cfargument name="host" required="true" type="string">

			<cfhttp method="get" url="#application.es.hosts[arguments.host].host#" result="esHost"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#">

			<cfset response = deserializeJson(indexStatus.fileContent)>

			<!--- If we recieved 404, return false --->
			<cfif response.status EQ "404">
				<cfreturn false>
			<!--- Otherwise index exists, return true --->
			<cfelse>
				<cfreturn true>
			</cfif>
	</cffunction>


	<!--- IS Existing Index --->
	<cffunction name="isExistingIndex" access="public" hint="Returns Boolean of if Index already exists on host">
		<cfargument name="host" required="true" type="string">
		<cfargument name="index" required="true" type="string">

			<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/#arguments.index#/" result="indexStatus"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#">

		<cfset response = deserializeJson(indexStatus.fileContent)>

		<!--- If we recieved 404, return false --->
		<cfif structKeyExists(response, "status") and response.status EQ "404">
			<cfreturn false>
		<!--- Otherwise index exists, return true --->
		<cfelse>
			<cfreturn true>
		</cfif>
	</cffunction>


	<!--- Check if Elastic is Running --->
	<cffunction name="isRunning" access="remote"  returnformat="plain" hint="Returns boolean if Elastic is currently running" >
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="returnType" default="json" type="string">

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/" result="indexStatus"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#">

		<cfif structKeyExists(deserializeJson(ping.filecontent), "version")>
			<cfreturn true>
		<cfelse>
			<cfreturn false>
		</cfif>
	</cffunction>

	<!--- Setup Elastic --->
	<cffunction name="setupElastic" access="remote" returnFormat="plain">
		<cfargument name="dataWhipe" default="false" type="string">
		<cfif arguments.dataWhipe>
			<cfinvoke component="index" method="deleteAllIndexes" />
		</cfif>
		<cfinvoke component="mappings" method="createAllMappings" />
		<cfinvoke component="index" method="indexAllData" />
	</cffunction>



	<!--- Get index Stats --->
	<cffunction name="getIndexStatus" access="remote" hint="Returns Stats about an Index">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="returnType" default="json" type="string">

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/#arguments.index#/_status" result="indexStatus"
						username="#application.es.hosts[arguments.host].shield.username#"
						password="#application.es.hosts[arguments.host].shield.password#">

		<cfif arguments.returnType EQ "json">
			<cfreturn status.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(status.fileContent)>
		</cfif>
	</cffunction>


	<!--- Index Data --->
	<cffunction name="indexData" access="remote" hint="sends a data object to elastic search for indexing">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="table" required="true" type="string">
		<cfargument name="data" required="true" type="struct">
		<cfargument name="id"  default="">
		<cfargument name="returnType" default="json" type="string">

		<cfhttp method="post" url="#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.table#/#arguments.id#" result="indexStatus"
					  username="#application.es.hosts[arguments.host].shield.username#"
						password="#application.es.hosts[arguments.host].shield.password#">
			<cfhttpparam  type="body" value="#serializeJson(arguments.data)#">
		</cfhttp>

		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(indexStatus)>
		<cfelse>
			<cfreturn indexStatus>
		</cfif>
	</cffunction>


	<!--- Create Index --->
	<cffunction name="createIndex" access="remote" hint="Creates an Elastic Search Index with Supplied Mapping.">
		<cfargument name="host" required="true" type="string">
		<cfargument name="name" required="true" type="string" hint="Name of Index to Create Mapping For">
		<cfargument name="type" default="" type="string" hint="ES Type of Index">
		<cfargument name="numShards" default="3" type="numeric" hint="Number of Shards for Index">
		<cfargument name="replicas" default="1" type="numeric" hint="Number of Replicas of Index">
		<cfargument name="mappings" required="true" type="struct" hint="Structure of Index Settings">
		<cfargument name="analyzers" type="array" hint="Custom Analyzers for Index">
		<cfargument name="returnType" default="json" type="string">

		<!--- Check if Index Exists --->
		<cfinvoke component="elastic" method="isExistingIndex" returnVariable="existingIndex">
			<cfinvokeargument name="host" value="#arguments.host#">
			<cfinvokeargument name="index" value="#arguments.name#">
		</cfinvoke>

		<!--- If we have type, append to URL --->
		<cfif arguments.type NEQ "">
			<cfset esUrl = "#application.es.hosts[arguments.host].host#/#arguments.name#/#arguments.type#">
		<cfelse>
			<cfset esUrl = "#application.es.hosts[arguments.host].host#/#arguments.name#">
		</cfif>

		<!--- If Index Doesnt Exist, Create using Provided Settings or Defaults [1 Rep, 3 Shards]--->
		<cfif !existingIndex>
			<cfset settings = structNew()>
			<cfset settings["index"] = structNew()>
			<cfset settings.index["number_of_shards"] = arguments.numShards>
			<cfset settings.index["number_of_replicas"] = arguments.replicas>

			<!--- If we have custom analyzers --->
			<cfif structKeyExists(arguments, "analyzers")>
				<cfset settings["index"]["analysis"] = {
					'analyzer': {}
				}>
				<!--- Add Analyzers to Settings Object --->
				<cfloop array="#arguments.analyzers#" index="i">
					<cfset settings.index.analysis.analyzer['#i.name#'] = {
						'tokenizer': i.tokenizer,
						'filter': i.filter
					}>
				</cfloop>
			</cfif>

			<cfset settings['mappings'] = arguments.mappings>

			<!--- Send Index Settings as Create Post to ES --->
			<cfhttp method="put" url="#application.es.hosts[arguments.host].host#/#arguments.name#" result="indexStatus"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#">
				<cfhttpparam  type="body" value="#serializeJson(settings)#" />
			</cfhttp>


		<cfelse>
			<!--- Put Request instead of Post since we arent including settings file for creation --->
			<cfhttp method="put" url="#esurl#/_mappings" result="indexStatus"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#">
				<cfhttpparam  type="body" value="#serializeJson(arguments.mappings)#" />
			</cfhttp>
		</cfif>



		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(indexStatus)>
		<cfelse>
			<cfreturn indexStatus>
		</cfif>
	</cffunction>


	<!--- Get Index Contents --->
	<cffunction name="getIndexContents" access="remote" hint="Returns Contents of an elastic Index">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="items" default="0" type="numeric">
		<cfargument name="returnType" default="json" type="string">

		<cfif arguments.items EQ 0>
			<cfset arguments.items = 10000>
		</cfif>

		<cfset result = structNew()>
		<cfset result.query = structNew()>
		<cfset result.query["match_all"] = structNew()>

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/#arguments.index#/_search?&size=#arguments.items#" result="index"
					  username="#application.es.hosts[arguments.host].shield.username#"
						password="#application.es.hosts[arguments.host].shield.password#">
			<cfhttpparam  type="body" value="#serializeJson(result)#">
		</cfhttp>

		<cfset scrollStruct = deserializeJson(index.fileContent)>

		<cfreturn scrollStruct >
	</cffunction>


	<!--- Get Data from Scroll ID --->
	<cffunction name="getScrollData" access="remote" hint="Returns Data from an Elastic Scroll ID">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="scrollID" type="string" required="true">
		<cfargument name="scrollTimeout" type="numeric" default="5" hint="Timeout of Elastics inner scrolling for this search. [Ms]">
		<cfargument name="returnType" default="json" type="string">

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/_search/scroll?scroll=#arguments.scrollTimeout#m&scroll_id=#arguments.scrollID#" result="scrollData"
					  username="#application.es.hosts[arguments.host].shield.username#"
						password="#application.es.hosts[arguments.host].shield.password#">

		<cfif arguments.returnType EQ "json">
			<cfreturn scrollData.fileContent>
		<cfelse>
			<cfreturn deserializeJson(scrollData.fileContent)>
		</cfif>
	</cffunction>

	<!--- Search index --->
	<cffunction name="searchIndex" returnFormat="plain" access="remote" hint="Returns Data from index">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" default="" type="string">
		<cfargument name="type" default="" type="string">
		<cfargument name="startItem" default="1" type="numeric">
		<cfargument name="endItem" default="10" tyoe="numeric">
		<cfargument name="searchType" default="basic" type="string">
		<cfargument name="includeScrollData" default="false" type="boolean">
		<cfargument name="returnType" default="json" type="string">
		<cfargument name="q" required="true">

		<cfif len(index) and len(table)>
			<cfset variables.serverUrl = "#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#">
		<cfelseif len(index)>
			<cfset variables.serverUrl = "#application.es.hosts[arguments.host].host#/#arguments.index#">
		<cfelse>
			<cfset variables.serverUrl = application.es.hosts[arguments.host].host>
		</cfif>


		<!--- If Basic Search Type --->
		<cfif arguments.searchType EQ "basic">

		<!--- Search Elastic --->
		<cfhttp method="get" url="#variables.serverUrl#/_search?q=#arguments.q#&search_type=scan&scroll=10m&size=10" result="searchResults"
		username="#application.es.hosts[arguments.host].shield.username#"
		password="#application.es.hosts[arguments.host].shield.password#">



		<!--- If Advanced Search --->
		<cfelse>

			<!--- Build Query Json Struct --->
			<cfhttp method="post" url="#variables.serverUrl#/_search?search_type=scan&scroll=1m&size=10&explain=true" result="searchResults"  charset="utf-8"
			username="#application.es.hosts[arguments.host].shield.username#"
			password="#application.es.hosts[arguments.host].shield.password#">
				<cfhttpparam type="body" value="#arguments.q#">
				<cfhttpparam type="header" name="Content-Length" value="#len(arguments.q)#">
				<cfhttpparam type="HEADER" name="Keep-Alive" value="300">
				<cfhttpparam type="HEADER" name="Connection" value="keep-alive">
				<cfhttpparam type="header" name="Content-Type" value="application/json; charset=utf-8" />
			</cfhttp>
		</cfif>

		<cfif arguments.includeScrollData>
			<cfset results = deserializeJson(searchResults.fileContent)>
			<!--- Get Scroll Data for This Page --->
			<cfinvoke component="cfc.elastic.Elastic" method="getScrollData" returnvariable="scrollData">
				<cfinvokeargument name="scrollID" value="#results['_scroll_id']#">
				<cfinvokeargument name="scrollTimeout" value="1">
				<cfinvokeargument name="returnType" value="struct">
			</cfinvoke>

			<cfset result = structNew()>
			<cfset result.searchInitial = structCopy(results)>
			<cfset result.scrollData = structCopy(scrollData)>
			<cfif arguments.returnType EQ "json">
				<cfreturn serializeJson(result)>
			<cfelse>
				<cfreturn result>
			</cfif>
		<cfelse>
			<cfif arguments.returnType EQ "json">
				<cfreturn searchResults.fileContent>
			<cfelse>
				<cfreturn deserializeJson(searchResults.fileContent)>
			</cfif>
		</cfif>

	</cffunction>




	<!--- ReMap Index --->
	<cffunction name="reMapIndex" access="remote" hint="Remaps an index from supplied Mapping Struct">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" type="string" required="true">
		<cfargument name="newMapData" type="struct" required="true">
		<cfargument name="returnType" default="json" type="string">

		<!--- Delete Index --->
		<cfinvoke component="elastic" method="deleteIndex" returnvariable="deletedDatabase">
			<cfinvokeargument name="index" value="#arguments.index#">
		</cfinvoke>


		<!--- Create Database --->
		<cfinvoke component="elastic" method="createIndex" returnvariable="createdDatabase">
			<cfinvokeargument name="index" value="#arguments.index#">
			<cfinvokeargument name="mappings" value="#arguments.newMapData#">
		</cfinvoke>

	</cffunction>


	<!--- Update Index Item --->
	<cffunction name="updateIndexItem" access="remote" hint="Submits a partial Update to an index item">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="table" default="" type="string">
		<cfargument name="itemID" required="true" type="numeric">
		<cfargument name="updatedItemData" required="true" type="struct">
		<cfargument name="returnType" default="json" type="string">

		<cfif len(index) and len(table)>
			<cfset variables.serverUrl = "#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.table#">
		<cfelseif len(index)>
			<cfset variables.serverUrl = "#application.es.hosts[arguments.host].host#/#arguments.index#">
		<cfelse>
			<cfset variables.serverUrl = application.es.hosts[arguments.host].host>
		</cfif>

		<cfset result = structNew()>
		<cfset result.doc = structCopy(arguments.updatedItemData)>

		<!--- Send Update Packet --->
		<cfhttp method="post" url="#variables.serverUrl#/#arguments.itemID#/_update?retry_on_conflict=5" result="updateResults"
		username="#application.es.hosts[arguments.host].shield.username#"
		password="#application.es.hosts[arguments.host].shield.password#">
			<cfhttpparam type="body" value="#serializeJson(result)#">
		</cfhttp>

		<cfif arguments.returnType EQ "json">
			<cfreturn updateResults.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(updateResults.fileContent)>
		</cfif>
	</cffunction>


	<!--- Delete Index --->
	<cffunction name="deleteIndex" access="remote" hint="Removes an index from elastic">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="type" default="" type="string">
		<cfargument name="returnType" default="json" type="string">

		<cfif len(arguments.table) and len(arguments.index)>
			<cfhttp method="delete" url="#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#"  result="deleteResults"
			username="#application.es.hosts[arguments.host].shield.username#"
			password="#application.es.hosts[arguments.host].shield.password#">
		<cfelse>
			<cfhttp method="delete" url="#application.es.hosts[arguments.host].host#/#arguments.index#"  result="deleteResults"
			username="#application.es.hosts[arguments.host].shield.username#"
			password="#application.es.hosts[arguments.host].shield.password#">
		</cfif>

		<cfif arguments.returnType EQ "json">
			<cfreturn deleteResults.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(deleteResults.fileContent)>
		</cfif>
	</cffunction>

	<!--- Delete Document --->
	<cffunction name="deleteDocument" access="remote" hint="Removes an document from elastic">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="type" default="" type="string">
		<cfargument name="id" required="true" hint="Document ID we are deleting" type="string">
		<cfargument name="returnType" default="json" type="string">

		<cfhttp method="delete" url="#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#/#arguments.id#"  result="deleteResults"
		username="#application.es.hosts[arguments.host].shield.username#"
		password="#application.es.hosts[arguments.host].shield.password#">

		<cfif arguments.returnType EQ "json">
			<cfreturn deleteResults.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(deleteResults.fileContent)>
		</cfif>
	</cffunction>

	<!--- Get Current Indexes --->
	<cffunction name="getCurrentIndexes" access="remote" returnformat="plain" hint="Get Current Indexes in Elastic Search">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="returnType" default="json" type="string">

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/_status" result="status"
		username="#application.es.hosts[arguments.host].shield.username#"
		password="#application.es.hosts[arguments.host].shield.password#">

		<cfif arguments.returnType EQ "json">
			<cfreturn status.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(status.fileContent)>
		</cfif>
	</cffunction>


	<!--- Get Index Settings --->
	<cffunction name="getIndexSettings" access="remote">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="returnType" default="json" type="string">
		<cfargument name="index" required="true" type="string">

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/#arguments.index#/_status" result="settings"
		username="#application.es.hosts[arguments.host].shield.username#"
		password="#application.es.hosts[arguments.host].shield.password#">

		<cfif arguments.returnType EQ "json">
			<cfreturn settings.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(settings.fileContent)>
		</cfif>
	</cffunction>


	<!--- Get Mappings for Index --->
	<cffunction name="getIndexMappings" access="remote">
		<cfargument name="host" default="#application.elastic.URL#" type="string">
		<cfargument name="returnType" default="json" type="string">
		<cfargument name="index" required="true" type="string">
		<cfargument name="table" default="" type="string">

		<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/#arguments.index#/_mapping/#arguments.table#" result="mapping"
		username="#application.es.hosts[arguments.host].shield.username#"
		password="#application.es.hosts[arguments.host].shield.password#">

		<cfif arguments.returnType EQ "json">
			<cfreturn mapping.fileContent>
		<Cfelse>
			<cfreturn deserializeJson(mapping.fileContent)>
		</cfif>
	</cffunction>

	<!--- Bulk Index --->
	<cffunction name="bulkIndex" access="public" hint="Submits Documents to Elastic Bulk API. Only Supports Single Index">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="update" type="boolean" default="false" hint="Boolean on if we are updating the document or creating it.">
		<cfargument name="index" required="true" type="string" hint="Index to Send Document To">
		<cfargument name="type" required="true" type="string" hint="Elastic Data Type">
		<cfargument name="documents" required="true" type="array" hint="Array of Documents to Submit in Request">
		<cfargument name="returnType" default="json" type="string" hint="Return Format of response">

		<!--- If we arent updating, set action to index [create] --->
		<cfif !arguments.update>
			<cfset variables.action = "index">
		<!--- If we are updating, set action to update --->
		<cfelse>
			<cfset variables.action = "update">
		</cfif>

		<!--- Create Result Struct --->
		<cfset returned = {
			'status': true,
			'itemCount': arrayLen(arguments.documents),
			'threads': []
		}>

		<!--- Set Line Break Character for Bulk Request Format --->
    <cfset br = "#chr(13)##chr(10)#">

	<!--- Create Current Doc Item Array --->
	 <cfset currentDocs = []>

	<!--- Create Empty Request String, We will Populate this will Bulk Request --->
	 <cfset currentRequest = "">

	<!--- If we are creating, construct index bulk array --->
	<cfif !arguments.update>
		<!--- Loop Documents --->
		<cfloop from="1" to="#arrayLen(arguments.documents)#" index="x">
			<!--- If First Row, Create First String --->
			<cfif x EQ 1>
				<cfif structKeyExists(arguments.documents[x], "id")>
					<cfset currentRequest = '{"#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#", "_id": #arguments.documents[x].id#}}#br##serializeJson(arguments.documents[x])##br#'>
				<cfelse>
					<cfset currentRequest = '{"#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#"}}#br##serializeJson(arguments.documents[x])##br#'>
				</cfif>
			<!--- If not First Row, Append String --->
			<cfelse>
				<cfif structKeyExists(arguments.documents[x], "id")>
					<cfset currentRequest = '#currentRequest# { "#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#", "_id": #arguments.documents[x].id# } }#br#'>
				<cfelse>
					<cfset currentRequest = '#currentRequest# { "#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#"} }#br#'>
				</cfif>
				<cfset currentRequest = '#currentRequest# #serializeJson(arguments.documents[x])##br#'>
			</cfif>
		</cfloop>
	</cfif>

	<!--- If we are updating, construct update bulk array --->
	<cfif arguments.update>
		<!--- Loop Documents --->
		<cfloop from="1" to="#arrayLen(arguments.documents)#" index="x">
			<!--- If First Row, Create First String --->
			<cfif x EQ 1>
				<!--- If we have ID --->
				<cfif structKeyExists(arguments.documents[x], "id")>
					<cfset currentRequest = '{"#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#", "_id": #arguments.documents[x].id#}}#br#{"doc": #serializeJson(arguments.documents[x])# }#br#'>
				<cfelse>
					<cfset currentRequest = '{"#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#"}}#br#{"doc": #serializeJson(arguments.documents[x])# }#br#'>
				</cfif>
			<!--- If not First Row, Append String --->
			<cfelse>
				<!--- If we have ID --->
				<cfif structKeyExists(arguments.documents[x], "id")>
					<cfset currentRequest = '#currentRequest#{"#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#", "_id": #arguments.documents[x].id# } }#br#'>
				<cfelse>
					<cfset currentRequest = '#currentRequest#{"#variables.action#": {"_index": "#arguments.index#", "_type": "#arguments.type#"} }#br#'>
				</cfif>
				<cfset currentRequest = '#currentRequest#{"doc": #serializeJson(arguments.documents[x])# }#br#'>
			</cfif>
		</cfloop>
	</cfif>


	<!--- Now that we have Formated Request, Send it to Elastic Search --->
	<cfhttp method="post" url="#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#/_bulk" result="indexResult"
			username="#application.es.hosts[arguments.host].shield.username#"
			password="#application.es.hosts[arguments.host].shield.password#"
			timeout="1">
			<cfhttpparam type="CGI" encoded="false" name="Content_Type" value="application/json; charset=utf-8">
		<cfhttpparam type="body" value="#currentRequest#">
	</cfhttp>

	<!--- Return Result Based on Requested Format [json,struct]--->
	<cfif arguments.returnType EQ "json">
		<cfreturn serializeJson(indexResult)>
	<Cfelse>
		<cfreturn indexResult>
	</cfif>
</cffunction>


	<!--- Get Suggestions --->
	<cffunction name="getSuggestions" access="public" hint="Returns Suggestions for a given term">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="index" type="string" required="true" hint="Index we are request suggestions from">
		<cfargument name="fields" type="array" required="true" hint="Field we are looking for suggestions in">
		<cfargument name="fuzzyness" type="numeric" default="5" hint="Field we are looking for suggestions in">
		<cfargument name="returnType" type="string" default="json" hint="Return Format of Results">
		<cfargument name="constructor" type="string" default="struct" hint="Data Variable Type thats Created. [Struct maintains requested result variable names]">

		<cfset esSuggestion = {}>

		<cfloop array="#arguments.fields#" index="i">
			<cfset esSuggestion['#i.result#'] = {
				"text": "#i.term#",
				"completion": {
					"field": "#i.field#",
					"fuzzy": {
						"fuzzyness": #arguments.fuzzyness#
					}
				}
			}>
		</cfloop>

		<!--- Now that we have Formated Request, Send it to Elastic Search --->
		<cfhttp method="post" url="#application.es.hosts[arguments.host].host#/#arguments.index#/_suggest" result="indexResult"
				username="#application.es.hosts[arguments.host].shield.username#"
				password="#application.es.hosts[arguments.host].shield.password#">
			<cfhttpparam type="body" value="#serializeJson(esSuggestion)#">
		</cfhttp>

		<cfset result = deserializeJson(indexResult.filecontent)>

		<cfif indexREsult.responseHeader.status_code EQ 500>
			<cfset result = result['_shards']>
		</cfif>

		<!--- Return Result Based on Requested Format [json,struct]--->
		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(result)>
		<Cfelse>
			<cfreturn result>
		</cfif>
	</cffunction>


	<!--- Get Similiar Documents [More_like_this es query] --->
	<cffunction name="getMoreLikeThis" access="public" hint="Returns Similiar Documents to request">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="type" default="" type="string" hint="Elastic Types we are limiting search to">
		<cfargument name="index" type="string" required="true" hint="Index we are request suggestions from">
		<cfargument name="text" type="string" required="true" hint="Field we are looking for suggestions in">
		<cfargument name="fields" type="array" required="true" hint="Fields we are looking for in">
		<cfargument name="returnFields" type="array"  hint="Fields we are returning">
		<cfargument name="filters" type="array"  hint="Filters if exist">
		<cfargument name="minTermCount" type="numeric" default="1" hint="Min Number of times term should occur">
		<cfargument name="maxTermCount" type="numeric" default="5" hint="Max Times the Term should occur">
		<cfargument name="returnType" type="string" default="json" hint="Return Format of Results">

		<!--- IF we have Filters --->
		<cfif structKeyExists(arguments, "filters") and arrayLen(arguments.filters)>
		<cfset mltQuery = {
			"fields": ['name'],
			'query': {
		    'filtered': {
					"query": {
					  "more_like_this" : {
				        "fields" : arguments.fields,
				        "like" : arguments.text,
				        "min_term_freq" : arguments.minTermCount,
				        "max_query_terms" : arguments.maxTermCount
					  }
					},
					'filter': { 'bool': { 'must': [] } }
				}
			}
		}>
		<!--- If we have filters, append them --->
		<cfloop array="#arguments.filters#" index="i">
			<cfset arrayAppend(mltQuery.query.filtered.filter.bool.must, i)>
		</cfloop>

	<!--- If we dont have filters --->
	<cfelse>
		<cfset mltQuery = {
			"fields": ['name'],
			'query': {
				  "more_like_this" : {
			        "fields" : arguments.fields,
			        "like" : arguments.text,
			        "min_term_freq" : arguments.minTermCount,
			        "max_query_terms" : arguments.maxTermCount
				  }
				}
		}>
	</cfif>

		<cfif arguments.type NEQ "">
			<cfset esURL = "#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#">
		<cfelse>
			<cfset esURL = "#application.es.hosts[arguments.host].host#/#arguments.index#">
		</cfif>

		<!--- Now that we have Formated Request, Send it to Elastic Search --->
		<cfhttp method="post" url="#esURL#/_search" result="indexResult"
				username="#application.es.hosts[arguments.host].shield.username#"
				password="#application.es.hosts[arguments.host].shield.password#">
			<cfhttpparam type="body" value="#serializeJson(mltQuery)#">
		</cfhttp>

		<cfset result = deserializeJson(indexResult.filecontent)>

		<cfif indexREsult.responseHeader.status_code EQ 500>
			<cfset result = result['_shards']>
		</cfif>

		<!--- Return Result Based on Requested Format [json,struct]--->
		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(result)>
		<Cfelse>
			<cfreturn result>
		</cfif>
	</cffunction>


	<!--- Get Phrase Suggestion --->
	<cffunction name="getPhraseSuggestion" access="public" hint="Returns Phrase match suggestions for supplied term">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="index" type="string" required="true" hint="Index we are request suggestions from">
		<cfargument name="term" type="string" required="true" hint="Text Term we are looking for suggestions for.">
		<cfargument name="field" type="string" required="true" hint="Field we are looking for in">
		<cfargument name="returnType" type="string" default="json" hint="Return Format of Results">
		<cfargument name="options" type="struct" hint="Optional Phrase Constructor Options. See ES Docs">

			<!--- Construct Default Query --->
			<cfset phraseQuery = {
				"suggest" : {
			    "text" : "#arguments.term#",
			    "simple_phrase" : {
						"phrase" : {
              "analyzer" : "default",
              "field" : "_all",
              "size" : 1,
              "real_word_error_likelihood" : 0.95,
              "max_errors" : 0.5,
              "gram_size" : 2,
              "direct_generator" : [ {
                "field" : "_all",
                "suggest_mode" : "always",
                "min_word_length" : 1
              } ],
              "highlight": {
                "pre_tag": "<em>",
                "post_tag": "</em>"
              }
            }
			    }
	  		}
			}>

			<!--- If we have options, overwrite defaults --->
			<cfif structKeyExists(arguments, "options")>
				<cfset phraseQuery.suggest.simple_phrase.phrase = arguments.options>
			</cfif>

			<!--- Now that we have Formated Request, Send it to Elastic Search --->
			<cfhttp method="post" url="#application.es.hosts[arguments.host].host#/#arguments.index#/_search" result="indexResult"
					username="#application.es.hosts[arguments.host].shield.username#"
					password="#application.es.hosts[arguments.host].shield.password#">
				<cfhttpparam type="body" value="#serializeJson(phraseQuery)#">
			</cfhttp>

			<cfset result = deserializeJson(indexResult.filecontent)>

			<cfif indexREsult.responseHeader.status_code EQ 500>
				<cfset result = result['_shards']>
			</cfif>

			<!--- Return Result Based on Requested Format [json,struct]--->
			<cfif arguments.returnType EQ "json">
				<cfreturn serializeJson(result)>
			<Cfelse>
				<cfreturn result>
			</cfif>
	</cffunction>


	<!--- Get Auto Complete --->
	<cffunction name="getAutocomplete" access="public" hint="Requests Auto Complete Results. Uses Prefix Query.">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="index" type="string" required="true" hint="Index we are request suggestions from">
		<cfargument name="type" type="string" required="true" hint="Document Type we are searching">
		<cfargument name="fields" type="array" required="true" hint="Array of fields we are looking for in">
		<cfargument name="match" type="array" required="true" hint="Array of Structures containing column name and boost value if applicable">
		<cfargument name="count" type="numeric" default="5" hint="Fields we are looking for in">
		<cfargument name="functions" type="array" hint="Functions Applied to Result Set">
		<cfargument name="returnType" type="string" default="json" hint="Return Format of Results">

		<!---
		TODO Add Regular non function prefix query

		ALLOW Session Functions for alternate results
		--->

		<!--- If we are using Function Scoring, Set Base Es Query --->
		<cfscript>
			/* Create Elastic Query [Json to send over HTTP] */
			esQuery = {
					/* Pagination Options */
					"from" :0, "size" : arguments.count,
					/* Return only ID since we already have the rest of the product data in application cache */
					"fields": arguments.fields,
					/* Main Query */
					 "query": {
					 /* Function Score Query allows us to Boost Results */
					 "function_score": {
						 /* Default Query Object, will be changed if param scope is filter */
							"query": {
								/* Bool Query to allow weighted should for relevance */
								"bool": {
									"minimum_should_match": 1,
									/* Show Clauses for Results */
									"should": []
								}
							},
							"functions": arguments.functions,
							/* Query Score Options */
						 "score_mode": "multiply",
						 "boost_mode": "multiply"
						}
					}
				};
				/* Add Should Clauses from Match Array */
				for(x=1; x<=arrayLen(arguments.match); x++){
					/* if we have boost for this clause */
					if(structKeyExists(arguments.match[x], "boost")){
						prefixItem = {"prefix" : { "#arguments.match[x].field#" :  { "value" : "#arguments.match[x].term#", "boost": arguments.match[x].boost } } };
					}
					else{
						prefixItem = {"prefix" : { "#arguments.match[x].field#" :  { "value" : "#arguments.match[x].term#" } } };
					}
					arrayAppend(esQuery.query.function_score.query.bool.should, prefixItem);
				}
		</cfscript>

		<!--- Now that we have our full query, Send to Elastic Search --->
		<cfhttp method="post" url="#application.es.hosts['products'].host#/#arguments.index#/_search"
						result="searchResponse"
						username="#application.es.hosts['products'].shield.username#"
						password="#application.es.hosts['products'].shield.password#">
					<cfhttpparam type="body" name="body" value="#serializeJson(esQuery)#">
		</cfhttp>

		<cfset result = deserializeJson(searchResponse.filecontent)>

		<cfif searchResponse.responseHeader.status_code EQ 500>
			<cfset result = result['_shards']>
		<cfelse>

			<cfset response = []>
			<cfloop array="#result.hits.hits#" index="i">
				<cfset arrayAppend(response, i.fields)>
			</cfloop>

			<cfset result = response>
		</cfif>

		<!--- Return Result Based on Requested Format [json,struct]--->
		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(result)>
		<Cfelse>
			<cfreturn result>
		</cfif>
	</cffunction>



	<!--- Get Document By ID --->
	<cffunction name="getDocumentByID" access="public" hint="Returns Document from ES index if exists by ID lookup">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="index" type="string" required="true" hint="Index we are getting document from">
		<cfargument name="type" type="string" required="true" hint="Document Type we getting">
		<cfargument name="id" type="string" required="true" hint="ID of document">
		<cfargument name="returnType" type="string" default="json" hint="Return Format of Results">

			<cfhttp method="get" url="#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#/#arguments.id#"
							result="esDocument"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#" />

			<cfset result = deserializeJson(esDocument.filecontent)>

		<!--- Return Result Based on Requested Format [json,struct]--->
		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(result)>
		<Cfelse>
			<cfreturn result>
		</cfif>
	</cffunction>


	<!--- Get All Document IDs --->
	<cffunction name="getAllDocumentIDs" access="public" hint="Gets all Document ID's in requested index and document Type">
		<cfargument name="host" required="true" type="string" hint="Elastic Host we are submitting the request to">
		<cfargument name="index" type="string" required="true" hint="Index we are getting document from">
		<cfargument name="type" type="string" required="true" hint="Document Type we getting">
		<cfargument name="returnType" type="string" default="json" hint="Return Format of Results">

			<cfset response = []>

			<cfset esQuery = {
				"from": 0,
				"fields": ["id"],
				"size": 10000,
			    "query" : {
			        "match_all" : {}
			    }
			}>
			<cfhttp method="post" url="#application.es.hosts[arguments.host].host#/#arguments.index#/#arguments.type#/_search"
							result="esDocument"
							username="#application.es.hosts[arguments.host].shield.username#"
							password="#application.es.hosts[arguments.host].shield.password#">
							<cfhttpparam type = "body" value="#serializeJson(esQuery)#" />
			</cfhttp>

			<cfset esItems = deserializeJson(esDocument.filecontent)>
			<cfset esItems = esItems.hits.hits>

			<cfloop array="#esItems#" index="i">
				<cfset arrayAppend(response, i._id)>
			</cfloop>

		<!--- Return Result Based on Requested Format [json,struct]--->
		<cfif arguments.returnType EQ "json">
			<cfreturn serializeJson(response)>
		<Cfelse>
			<cfreturn response>
		</cfif>

	</cffunction>


	<!--- Creates Es String for Search and Recieve [Prevents issues with matching on strings with special characters] --->
	<cffunction name="createEsString" access="public" hint="Converts a string into a ES compatible search value. [Models with -'s or special characters]">
		<cfargument name="string" type="string" required="true" hint='String we are converting'>
		<cfset str = arguments.string>
		<!--- Strings to remove --->
		<cfset values = ['-','&','##','%','_','~',':',';','^','$','@','}','{','`','!','|','"']>
		<cfloop array="#values#" index="i">
			<cfset str =  reReplace(str, i, '', 'all')>
		</cfloop>
		<cfreturn str>
	</cffunction>

</cfcomponent>
