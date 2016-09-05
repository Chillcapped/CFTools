<!---
	Component Handles Event Logging
		Requires Logstash UDP Server

	Methods
		-init
		-createCampaignCookie
		-logEvent
		-sendUDP
--->
<cfcomponent output="no">

	<!--- Handles Event Logging --->
	<cffunction name="init" access="public" hint="Initialize Application Logging Variables">
		<cfargument name="environment" type="struct" required="true" hint="Environment Variables">

		<!---
			Initialize Default Logging Variables
			Host IP Must be logstash server with configuration file to listen for UDP packets

			Host variable is a cached java object for sending

			Elastic Index is Updated with Parsed UDP Packet Data using daily indexes
		--->
		<cfset application.logging = {
				host: createObject("java", "java.net.InetAddress").getByName('LOGSTASH SERVER IP'),
				port: 8080,
				errorCount: 0,
				enabled: false
		}>

		<!--- If we have Host from Environment --->
		<cfif structKeyExists(arguments.environment.logging, "host")>
			<cfset application.logging.host = createObject("java", "java.net.InetAddress").getByName(arguments.environment.logging.host)>
		</cfif>

		<!--- If we have Port --->
		<cfif structKeyExists(arguments.environment.logging, "port")>
			<cfset application.logging.port = arguments.environment.logging.port>
		</cfif>

		<!--- if we have enabled logging --->
		<cfif structKeyExists(arguments.environment.logging, "enabled")>
			<cfset application.logging.enabled = arguments.environment.logging.enabled>
		</cfif>

		<cfreturn true>
	</cffunction>


	<!--- Set Event Cookie--->
	<cffunction name="createCampaignCookie" access="public" returnType="string" hint="sets cookie based on campaign string">
		<cfargument name="campaign" type="string" required="true">
			<!--- If cookie doesnt exist create it, --->
			<cfif !structKeyExists(cookie, "campaign")>
				<!--- Set Cookie to never expire --->
				<cfcookie name="campaign" value="#arguments.campaign#" expires="never" preserveCase="true">
				<!--- Add Campaign to session so we dont have to read cookies everyime we want to reference it --->
				<cfset session['campaign'] = arguments.campaign>
			<!--- If cookie exists (Function is called when ?campaign= exists in the url params)
			--->
			<cfelse>
				<!--- If cookie and campaign dont match, user clicked on additional campaign link --->
				<cfif cookie.campaign NEQ arguments.campaign>
					<!--- Send Log to report duplicate ad event --->
					<cfset additionalLog = {
						'duplicate': true,
						'first_campaign': cookie.campaign,
						'secondary_campaign': arguments.campaign
					}>
					<!--- Log Page View Event  --->
					<cfinvoke component="cfc.logging.events" method="logEvent">
						<cfinvokeargument name="etype" value="campaign">
						<cfinvokeargument name="url" value="#request.CGI.PATH_INFO#">
						<cfinvokeargument name="additional" value="#additionalLog#">
					</cfinvoke>
					<!--- Overwrite previous value --->
					<cfcookie name="campaign" value="#arguments.campaign#" expires="never" preserveCase="true">
					<cfset session['campaign'] = arguments.campaign>
				</cfif>
			</cfif>
	</cffunction>

	<!--- Log Event --->
	<cffunction name="logEvent" access="public" returnType="string" hint="Logs Event to logstash http server">
		<cfargument name="etype" type="string" required="true" hint="type of event">
		<cfargument name="message" type="string" default="" hint="message to log">
		<cfargument name="key" type="string" hint="Unique Key related to event">
		<cfargument name="url" type="string" hint="URL event occured">
		<cfargument name="additional" type="struct" hint="Additional Data Items added to Log">
		<cfargument name="grokFilter" type="string" default="frontEnd" hint="Type of Grok Filters for Logstash to Run. [FrontEnd,Shipping,Backend]">

			<!-- Wrap log attempt in CFtry block --->
			<cftry>
				<!--- Create Default Event Struct --->
				<cfset logEvent = {
					'description': arguments.message,
					'etype': arguments.etype,
					'grokFilter': arguments.grokFilter,
					'ip': cgi.remote_addr,
					'site': cgi.server_name
				}>

				<!--- If we are Logging FRont End Data [Include Relevant Data] --->
				<cfif arguments.grokFilter EQ "frontEnd">
					<cfset logEvent['userAgent'] = cgi.http_user_agent>
					<cfset logEvent['cookies'] = cgi.http_cookie>
					<cfset logEvent['referer'] = cgi.http_referer>
				</cfif>

				<!--- If this is a shipping Event [Create Full Shipping String from Log Data] --->
				<cfif arguments.grokFilter EQ "shipping">

				</cfif>

				<!--- If this is a backend event [] --->
				<cfif arguments.grokFilter EQ "backend">

				</cfif>

				<!--- If we have a unique ID Key assosciated with this log --->
				<cfif structKeyExists(arguments, "key")>
					<cfset logEvent['key'] = arguments.key>
				</cfif>

				<!--- If we have sessionID add it --->
				<cfif structKeyExists(session, "sessionID")>
					<cfset logEvent['sessionID'] = session.sessionID>
				</cfif>

				<!--- If we have Adwords info in Session add it --->
				<cfif structKeyExists(session, "adwords")>
					<cfset logEvent['adwords'] = session.adwords>
				</cfif>

				<!--- If we have campaign in session, add it and set tracking to true --->
				<cfif structKeyExists(session, "campaign")>
					<cfset logEvent['campaign'] = session.campaign>
					<cfset logEVent['campTrack'] = true>
				</cfif>

				<!--- If we have CartID, add it --->
				<cfif structKeyExists(session, "cart") and structKeyExists(session.cart, "id")>
					<cfset logEvent['cartID'] = session.cart.ID>
				</cfif>

				<!--- If we have quoteID, add it --->
				<cfif structKeyExists(session, "quote") and structKeyExists(session.quote, "id")>
					<cfset logEvent['quoteID'] = session.quote.ID>
				</cfif>

				<!--- If URL Exists in Params, add it --->
				<cfif structKeyExists(arguments, "url")>
					<cfset logEvent['request'] = arguments.url>
				</cfif>

				<!--- Append Additional Data Items to Log if Exist --->
				<cfif structKeyExists(arguments, "additional")>
					<cfloop collection="#arguments.additional#" item="i">
						<cfset logEvent['#i#'] = arguments.additional[i]>
					</cfloop>
				</cfif>

				<!--- Send to Logstash HTTP Server --->
				<cfinvoke component="cfc.logging.events" method="sendUDP" returnVariable="udp">
				  <cfinvokeargument name="message" value="#serializeJson(logEvent)#">
				</cfinvoke>

				<!--- Return true if success--->
				<cfreturn true>
			<!--- If failed to Log --->
			<cfcatch></cfcatch>
		</cftry>
	</cffunction>


	<!---
	 Sends a UDP packet.
	 @param host 	 Host to send the UDP (Required)
	 @param port 	 Port to send the UDP (Required)
	 @param message 	 The message to transmit (Required)
	 @return Returns nothing.
	--->
	<cffunction name="sendUDP" access="public" returntype="string" output="false">
		<cfargument name="message" type="string" required="yes"  hint="The message to transmit">
		<cfset var text = arguments.message />
		<cfset var msg = arraynew(1) />
		<cftry>
			<cfset var i = 0>
			<cfloop index="i" from="1" to="#len(text)#">
				<cfset msg[i] = asc( Mid(text, i, 1) ) />
			</cfloop>

			<!--- Initialize a datagram packet with data and address --->
			<cfset packet = createObject("java", "java.net.DatagramPacket").init(
			  javacast("byte[]",msg),
			  javacast("int",arrayLen(msg)),
			  application.logging.host,
			  javacast("int",application.logging.port)) />

			<!--- Create a datagram socket, send the packet through it, close it. --->
			<cfset dsocket = createObject("java", "java.net.DatagramSocket") />
			<cfset dsocket.send(packet) />
			<cfset dsocket.close() />
			<cfcatch></cfcatch>
		</cftry>
	</cffunction>


</cfcomponent>
