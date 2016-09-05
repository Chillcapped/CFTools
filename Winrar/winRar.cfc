<cfcomponent>
	<!---
		Component Includes Function to UnRar
		Requires Rar.exe in folder [Not included in repo]
	--->

	<!--- Unrar File --->
	<cffunction name="Unrar" access="public" returnType="boolean" output="false">
	    <cfargument name="archivefile" type="string" required="true">
	    <cfargument name="destination" type="string" required="true">
	    <cfset var exeName = "">
	    <cfset var result = "">
	    <cfset var errorresult = "">


	    <cfif not fileExists(arguments.archivefile)>
	        <cfthrow message="Unable to work with #arguments.arvhiefile#, it does not exist.">
	    </cfif>

	    <cfif findnocase(".rar",arguments.archivefile)>
	        <cfset var exeName = expandpath("./Rar.exe" )>
	        <cfset var args = []>
	        <cfif directoryExists(#arguments.destination#)>
	            <cfset args[1] = "x +o">
	        <cfelse>
	            <cfset directoryCreate(#arguments.destination#)>
	            <cfset args[1] = "x">
	        </cfif>
	        <cfset args[2] = arguments.archivefile>
	        <cfset args[3] = "#arguments.destination#">
	    </cfif>
	    <cfexecute name="#exeName#" arguments="#args#" variable="result" errorvariable="errorresult" timeout="99" />

	    <cfif findNoCase("OK All OK", result)>
	        <cfreturn true>
	    <cfelse>
	        <cfreturn false>
	    </cfif>
	</cffunction>

</cfcomponent>
