<!---
      CFC For integrating with Full Contact Api
      https://www.fullcontact.com/

      Responses from Full Contact API are logged in 'fullcontact_api_data' table
      of mysql database

      Requires MySQl Database configured in CFIDE
--->
<cfcomponent>

      <cffunction name="init">
            <cfset application.fullContact = structNew()>
            <cfset application.fullContact.apiKey = "API-KEY">
            <cfset application.fullContact.elasticCache = true>
            <cfset application.fullContact.mySqlBackup = true>
            <cfset application.fullContact.mySQlDB = "customers">
            <cfset application.fullContact.personLookupURL = "https://api.fullcontact.com/v2/person.json">
      </cffunction>


      <!--- Lookup Email --->
      <cffunction name="lookupEmail" access="remote" returnFormat="plain">
            <cfargument name="email" type="string" required="true">
            <cfargument name="customerID" type="numeric" default="0">
            <cfargument name="force" type="string" default="true">
            <cfargument name="returnType" type="string" default="json">


            <cfset result = structNew()>
            <cfset result.hitApi = false>
            <cfset result.status = true>
            <cfset result.force = arguments.force>
            <!--- If we are using elastic cache --->
            <cfif application.fullContact.elasticCache>
                  <cfhttp method="get" url="#application.elastic.URL#/fullcontact/emails/_search?q=#arguments.email#&size=1" result="results"
                  username="#application.elastic.shield.username#"
      		password="#application.elastic.shield.password#"/>

                  <cfif structKeyExists(variables, "results") and structKeyExists(results, "fileContent")>
                        <cfset results = deserializeJson(results.fileContent)>
                        <cfif arrayLen(results.hits.hits)>
                              <cfset contactData = results.hits.hits[1]['_source']>
                              <cfset contactID = results.hits.hits[1]['_id']>
                              <cfset foundInCache = true>
                        <cfelse>
                              <cfset foundInCache = false>
                        </cfif>
                  <cfelse>
                        <cfset foundInCache = false>
                  </cfif>
            </cfif>

            <cfif foundInCache>
                  <cfset result.foundInCache = true>
                  <cfset result.contactData = contactData>

            </cfif>

            <cfif !foundInCache or arguments.force>
                  <cfset result.hitApi = true>

                  <cfhttp method="get" url="#application.fullCOntact.personLookupURL#" result="fullContactData">
                        <cfhttpparam type="url" name="apiKey" value="#application.fullContact.apiKey#" />
                        <cfhttpparam type="url" name="email" value="#arguments.email#" />
                  </cfhttp>

                  <cfset fullContactStruct = deserializeJson(fullContactData.fileContent)>
                  <cfset fullContactStruct.email = arguments.email>
                  <cfset fullContactStruct.customerID = arguments.customerID>

                  <!--- Save In Mysql --->
                  <cfif application.fullContact.mySqlBackup and !structKeyExists(variables, "contactID")>
                        <cfquery name="insertMySQlRecord" datasource="#application.fullContact.mySqlDB#" result="savedApiResponse">
                              insert into fullcontact_api_data
                              (email,lastUpdate,dateCreated,jsonData,statusCode,customerID)
                              values
                              (
                              <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.email#">,
                              <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                              <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                              <cfqueryparam cfsqltype="cf_sql_varchar" value="#serializeJson(fullContactStruct)#">,
                              <cfqueryparam cfsqltype="cf_sql_integer" value="#fullContactData.responseheader['Status_Code']#">,
                              <cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.customerID#">
                              )
                        </cfquery>
                        <cfset contactID = savedApiResponse.generated_key>
                        <cfset result.mysqlRecord = "created">
                  <!--- If we are forcing, update with most current Data --->
                  <cfelseif application.fullContact.mySqlBackup and structKeyExists(variables, "contactID")>
                        <cfquery name="updateMySQlRecord" datasource="">
                              update fullcontact_api_data
                              set lastUpdate = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
                                  jsonData = <cfqueryparam cfsqltype="cf_sql_varchar" value="#serializeJson(fullContactStruct)#">,
                                  statusCode= <cfqueryparam cfsqltype="cf_sql_integer" value="#fullContactData.responseheader['Status_Code']#">,
                                  customerID= <cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.customerID#">)
                              where dataID = <Cfqueryparam cfsqltype="cf_sql_integer" value="#contactID#">
                        </cfquery>
                        <cfset result.mysqlRecord = "updated">
                  </cfif>

                  <!--- Send Data to Elastic --->
                  <cfinvoke component="cfc.elastic.elastic" method="indexData" returnvariable="indexStatus">
                        <cfinvokeargument name="data" value="#fullContactStruct#">
                        <cfinvokeargument name="index" value="fullcontact">
                        <cfinvokeargument name="table" value="emails">
                        <cfinvokeargument name="returnType" value="struct">
                        <cfinvokeargument name="id" value="#contactID#">
                  </cfinvoke>

                  <!--- Elastic Update on Customer ID IF exists --->

                  <cfset result.contactData = fullContactStruct>
            </cfif>

            <cfif arguments.returnType EQ "json">
                  <cfreturn serializeJson(result)>
            <cfelse>
                  <cfreturn result>
            </cfif>
      </cffunction>



</cfcomponent>
