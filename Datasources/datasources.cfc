<cfcomponent>
  <!---
    Component Includes Functions to make adding multiple datasources into CFIDE easier.

    Its a huge bummer when setting up new coldfusion instances if your application requires alot
    of datasources.

    Drop this component into an empty webroot and execute the methods remotely. CF Account used
    must have access to AdminAPI

    [site]/datasources.cfc?method=getDatasources
    [site]/datasources.cfc?method=createAppDatabases
  --->

  <!--- Get Current Datasources in CFIDE --->
  <cffunction name="getDatasources" returnFormat="JSON" access="remote" returnFormat="plain">
    <cfargument name="password" default="root" hint="CFIDE Administrator Account Password">

    <!--- Log in to the CF admin with your password --->
    <cfset adminAPI = createObject( 'component', 'cfide.adminapi.administrator' ) />
    <cfset adminAPI.login( arguments.password ) />

      <!--- Loop over our query and create datasources for each database in MySQL --->
    	<cfscript>
    	dsnAPI = createObject( 'component', 'cfide.adminapi.datasource' );

    	// Finally, we save the new datasource
      datasources = dsnAPI.getDatasources();
    	</cfscript>

      <cfreturn datasources>
  </cffunction>

  <!--- Create Application Datasources --->
  <cffunction name="createAppDatabases" access="remote" returnFormat="JSON">
    <cfargument name="cfpassword" type="string" required="true" hint="CFIDE Password">
    <cfargument name="user" type="string" default="root" hint="MySQL UserName">
    <cfargument name="password" type="string" required="true" hint="MySQL password">
    <cfargument name="host" type="string" default="localhost" hint="MySQL Host IP">
    <cfargument name="port" type="string" default="localhost" hint="MySQL Port">
    <cfargument name="datasources" type="string" default="cms,cms_meta" hint="CSV of Datasources to Add">

    <cfset datasources = listToArray(datasources)>
    <!--- Log in to the CF admin  --->
    <cfset adminAPI = createObject( 'component', 'cfide.adminapi.administrator' ) />
    <cfset adminAPI.login( arguments.cfpassword ) />

    <cfloop from="1" to="#arrayLen(datasources)#" index="i">
    	<cfscript>
    	dsnAPI = createObject( 'component', 'cfide.adminapi.datasource' );
    	// Create a struct that contains all the information for the
    	// datasource. Most of the keys are self explanatory, but I
    	// had trouble finding the one for the connection string setting.
    	// Turns out that the key is "args"
    	dsn = {
    		driver = 'mysql5',
    		name = datasources[i],
    		host = arguments.host,
    		port = arguments.port,
    		database = datasources[i],
    		username = arguments.user,
    		password = arguments.password,
    		args = 'allowMultiQueries=true'
    	};
    	// Finally, we save the new datasource
    	dsnAPI.setMySQL5( argumentCollection = dsn );
    	</cfscript>
    </cfloop>
    <cfreturn datasources>
  </cffunction>


</cfcomponent>
