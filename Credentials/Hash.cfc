<cfcomponent>

<!--- Compute Hash --->
<cffunction name="computeHash" access="public" returntype="String">
  <cfargument name="password" type="string" />
  <cfargument name="salt" type="string" />
  <cfargument name="iterations" type="numeric" required="false" default="1024" />
  <cfargument name="algorithm" type="string" required="false" default="SHA-512" />
  <cfscript>
    var hashed = '';
    var i = 1;
    hashed = hash( password & salt, arguments.algorithm, 'UTF-8' );
    for (i = 1; i <= iterations; i++) {
      hashed = hash( hashed & salt, arguments.algorithm, 'UTF-8' );
    }
    return hashed;
  </cfscript>
</cffunction>

<!--- Generate Salt --->
<cffunction name="genSalt" access="public" returnType="string">
    <cfargument name="size" type="numeric" required="false" default="16" />
    <cfscript>
     var byteType = createObject('java', 'java.lang.Byte').TYPE;
     var bytes = createObject('java','java.lang.reflect.Array').newInstance( byteType , size);
     var rand = createObject('java', 'java.security.SecureRandom').nextBytes(bytes);
     return toBase64(bytes);
    </cfscript>
</cffunction>


</cfcomponent>
