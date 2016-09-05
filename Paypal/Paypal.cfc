<cfcomponent hint="Handles Paypal Interaction">

  <!---
    Component Handles Paypal API Interaction
    Includes CC Payment Processing. Paypal Account Purchases are not currently supported.

    Uses Payflow Link API

  --->

  <!--- Initialize Paypal Settings [Called on Application Start] --->
  <cffunction name="initialize" access="public" hint="Initialize Application Variables for Paypal Payments">
    <cfargument name="environment" type="struct" required="true" hint="Environment Variables For Application Settings">
    <cfargument name="decrypt" type="boolean" default="false" hint="Boolean on whether to decrypt environment settings">
    <cfargument name="credentials" type="struct" hint="Optional Credentials Object">

    <!--- If we have supplied credentials --->
    <cfif structKeyExists(arguments, "credentials")>
      <cfset credentials = {
       'user': arguments.credentials.user,
        'pass': arguments.credentials.pass,
        'partner': arguments.credentials.partner
      }>
    <!--- If we dont have Credentials Supplied Seperatly, Check Env File --->
    <cfelse>a
      <cfset credentials = {
        'user': arguments.environment.paypal.auth.user,
        'pass': arguments.environment.paypal.auth.password,
        'partner': arguments.environment.paypal.auth.partner
      }>
    </cfif>

    <!--- Default Paypal Cache Variable [Sandbox URL for Payflow API]--->
    <cfset application.payments.paypal = {
      "mode": "development",
      "method": "payflow",
      "api": "https://pilot-payflowpro.paypal.com",
      "accepted": ["amex","visa","mastercard","discover"],
      "proxy": {
       'port': 0,
       'name': '',
       'enabled': false
      },
      "credentials": credentials
    }>

    <!--- Set Paypal URL To Testing Mode if Localhost --->
    <cfif application.wheels.environment EQ "development" or application.wheels.environment EQ "testing">
      <cfset application.payments.paypal.api = "https://pilot-payflowpro.paypal.com">
    <!--- Set Paypal URL to Production if not Testing --->
    <cfelse>
      <cfset application.payments.paypal.api = "https://payflowpro.paypal.com">
    </cfif>

    <!--- If we have Payments Object in Environment File for Paypal --->
    <cfif structKeyExists(arguments.environment, "payments") and structKeyExists(arguments.environment.payments, "paypal")>

    <!--- If we have REquired environment variables to set sandbox url --->
    <cfif structKeyExists(arguments.environment.payments.paypal, "mode")
      and structKeyExists(arguments.environment.payments.paypal, "url_sandbox")
      and arguments.environment.payments.paypal.mode EQ "sandbox">

      <!--- Set API URL --->
     <cfset application.payments.paypal.api = arguments.environment.payments.paypal.url_sandbox>

    <!--- If we have required environment variables to set production url --->
    <cfelseif structKeyExists(arguments.environment.payments.paypal, "mode")
          and structKeyExists(arguments.environment.payments.paypal, "url_production")
          and arguments.environment.payments.paypal.mode EQ "production">

    <!--- Set API URL --->
     <cfset application.payments.paypal.api = arguments.environment.payments.paypal.url_production>

    </cfif>

    <!--- If we have required environment variables to overwrite accepted payment types --->
    <cfif structKeyExists(arguments.environment.payments.paypal, "accepted")>
      <cfset application.payments.paypal.accepted = arguments.environment.payments.paypal.accepted>
    </cfif>

    <!--- End of If we have Paypal Environment Variables --->
    </cfif>


  <!--- Store Request Body Header That Contains APplication Credentials --->
  <cfset application.payments["Paypal"]['body'] =
        "USER[#len(application.payments["Paypal"].credentials.user)#]=#application.payments["Paypal"].credentials.user#&"&
        "PWD[#len(application.payments["Paypal"].credentials.pass)#]=#application.payments["Paypal"].credentials.pass#&"&
        "PARTNER[#len(application.payments["Paypal"].credentials.partner)#]=#application.payments["Paypal"].credentials.partner#&"&
        "VENDOR[#len(application.payments["Paypal"].credentials.user)#]=#application.payments["Paypal"].credentials.user#&">
    <cfreturn true>
  </cffunction>

  <!--- Submit Payment [Uses Payflow Link API] --->
  <cffunction name="submitPayment" access="public" hint="Submits Payment Information to Paypal API">
    <cfargument name="cart" type="struct" required="true" hint="Customers Cart Object">
    <cfargument name="cc" required="true" type="string" hint="Customer Credit Card Number">
    <cfargument name="ammount" required="true" type="numeric" hint="Order Total Ammount">
    <cfargument name="tender" default="C" type="string" hint="Order Total Ammount">
    <cfargument name="method" default="cc" type="String" hint="Method of Payment. Defaults to CC">
    <cfargument name="type" required="true" type="string" hint="Request Type [Authroization, Charge]">
    <cfargument name="street" required="true" type="string" hint="Customers Street Address">
    <cfargument name="ccExpDate" required="true" type="string" hint="Customers Credit Card Experation Date">
    <cfargument name="cvcCode" required="true" type="string" hint="Customer Credit Card CVC Code">
    <cfargument name="zip" required="true" type="string" hint="Customer Billing Zip Code">
    <cfargument name="verbosity" default="MEDIUM" type="string" hint="Debug Value">
    <cfargument name="log" default="true" type="boolean" hint="Boolean. Send to Logstash">
    <cfargument name="returnType" type="string" default="struct" hint="Struct/JSON">
    <cfargument name="sessionID" type="string" required="true" hint="Customers Current SessionID">
    <cfargument name="validate" type="boolean" default="false" hint="Boolean if we are validating customers submission">
    <cfargument name="domain" type="numeric" default="1" hint="Domain ID Order was Placed on">

    <!--- Create Default Response object and ID for Paypal Request --->
    <cfset response = {
      id: left(rereplace(createUUID(), "-", "", "all"), 10),
      method: arguments.method,
      success: false
    }>

    <!--- Create Payment Info Struct we will pass into order save --->
    <cfset paymentInfo = {
      'card': {
        'number': arguments.cc,
        'expMonth': left(arguments.ccExpDate, 2),
        'expYear': right(arguments.ccExpDate, 2)
      },
      'total': arguments.ammount,
      'type': 'cc'
    }>

    <!--- Use Account Body Prefix --->

    <!--- Construct Body String For Paypal API Request --->
    <cfset requestBody = application.payments.paypal.body &
      "TRXTYPE[#len(arguments.type)#]=#arguments.type#&"&
      "TENDER[#len(arguments.tender)#]=#arguments.tender#&"&
      "AMT[#len(arguments.ammount)#]=#arguments.ammount#&"&
      "EXPDATE[#len(arguments.ccexpDate)#]=#arguments.ccexpDate#&"&
      "ACCT[#len(arguments.cc)#]=#arguments.cc#&"&
      "VERBOSITY[#len(arguments.verbosity)#]=#arguments.verbosity#&"&
      "street[#len(arguments.street)#]=#urlEncodedFormat(arguments.street)#&"&
      "zip[#len(arguments.zip)#]=#arguments.zip#&"&
      "cvv2[#len(arguments.cvcCode)#]=#arguments.cvcCode#&"&
      "custIP[#len(arguments.ip)#]=#arguments.ip#&"&
      "REQUEST_ID[#len(response.id)#]=#response.id#">

    <!--- Submit to Paypal --->
    <cfhttp url="#application.payments.paypal.api#" result="paypalResponse" method="post" resolveurl="yes" timeout="30">
     <cfhttpparam type="header" name="Connection" value="close">
     <cfhttpparam type="header" name="Content-Type" value="text/namevalue">
     <cfhttpparam type="header" name="Content-Length" value="#Len(requestBody)#">
     <cfhttpparam type="header" name="Host" value="#application.payments.paypal.api#">
     <cfhttpparam type="header" name="X-VPS-REQUEST-ID" value="#response.id#">
     <cfhttpparam type="header" name="X-VPS-CLIENT-TIMEOUT" value="30">
     <cfhttpparam type="header" name="X-VPS-VIT-Integration-Product" value="Coldfusion">
     <cfhttpparam type="header" name="X-VPS-VIT-Integration-Version" value="11.0">
     <cfhttpparam type="body" encoded="no" value="#requestBody#">
    </cfhttp>

    <!--- Process Response --->
    <cfinvoke component="paypal" method="processResponse" returnVariable="processedResponse">
      <cfinvokeargument name="response" value="#paypalResponse.filecontent#">
      <cfinvokeargument name="cart" value="#arguments.cart#">
      <cfinvokeargument name="log" value="true">
    </cfinvoke>

    <!--- Construct Response --->
    <cfset response = {
      paypalResponse: processedResponse,
      valid: true,
      message: "success",
      payment: arguments.ammount
    }>

    <!--- Store Order --->
    <cfinvoke component="paypal" method="savePayment" returnVariable="savedresponse">
      <cfinvokeargument name="payment" value="#paymentInfo#" />
      <cfinvokeargument name="paypalResponse" value="#processedResponse#" />
      <cfinvokeargument name="cart" value="#arguments.cart#" />
      <cfinvokeargument name="sessionID" value="#arguments.sessionID#" />
      <cfinvokeargument name="ip" value="#arguments.ip#" />
      <cfinvokeargument name="domain" value="#arguments.domain#" />
    </cfinvoke>

    <!--- Set Order Number that we get back from Database Save --->
    <cfset response.orderID = savedResponse.orderID>

    <!--- Send Order Confirmations --->

    <cfif arguments.returnType EQ "json">
      <cfreturn serializeJson(response)>
    <cfelse>
      <cfreturn response>
    </cfif>
  </cffunction>

  <!--- Process Response --->
  <cffunction name="processResponse" access="public" hint="Process Payment Gateway Response">
    <cfargument name="returnType" default="struct" type="string">
    <cfargument name="response" required="true" type="string">
    <cfargument name="cart" required="true" type="struct">

    <cfset responseStruct = structNew()>
    <cfset logData = {
        'cartID': arguments.cart.id
    }>

    <!--- loop each param returned in encoded contents, break at each '&' char --->
    <cfloop list="#arguments.response#" delimiters="&" index="line">
      <!--- find = sign, everything to left is formFieldName, everything to right is value --->
      <cfset break = Find("=", line)>
      <cfset leftBreak = break - 1>
      <cfset rightBreak = len(line) - break>
      <!--- break values at points to parse --->
      <cfset formField = left(line, leftBreak)>
      <cfset value = right(line, rightBreak)>
      <!--- put results into a structure --->
      <cfset logData["pp#formField#"] = value>
      <cfset responseStruct["#formField#"] = value>
    </cfloop>


    <cfreturn responseStruct>
  </cffunction>

  <!--- Save Payment Record --->
  <cffunction name="savePayment" access="public" hint="Saves Customers Order in Database">
    <cfargument name="payment" type="struct" required="true" hint="Customer Payment Information">
    <cfargument name="paypalResponse" type="struct" required="true" hint="Paypal Response of Payment Request">
    <cfargument name="cart" type="struct" required="true" hint="Customers Shopping Cart Info. [typically session.cart]">
    <cfargument name="sessionID" type="string" required="true" hint="Customers Session ID">
    <cfargument name="domain" type="numeric" required="true" hint="Domain Order was Placed on">

      <!--- Custom App Logic for Handling Payment --->

      <cfreturn response>
  </cffunction>

</cfcomponent>
