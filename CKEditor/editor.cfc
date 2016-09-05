<cfcomponent>
		<!--- Render Post in WIZY  [CKeditor] Editor [FOR IFRAME]--->
		<cffunction name="renderCKEditor" access="remote" returnFormat="plain">
			<cfargument name="html" type="string" default="">
      <cfargument name="height" type="numeric" default="700">
      <cfargument name="width" type="numeric" default="840">
			<cfsavecontent variable="htmlPage">
	      <script src="/bower_components/jquery/jquery.min.js"></script>
				<style>
				.cke_source{
				  padding-left: 11px;
				padding-right: 6px;
				padding-top: 11px;
				}
				</style>
	      <textarea class="ckeditor" id="editor" name="editor" rows="25" style="display:none;">
	            <cfoutput>#arguments.html#</cfoutput>
	      </textarea>
	      <script type="text/javascript">
          $(document).ready(function(){
                var editor = CKEDITOR.replace('editor', {
                    language: 'en',
                      <cfoutput>
                      height: #arguments.height#,
                      width: #arguments.width#,
                      </cfoutput>
                      allowedContent: true,
                      forcePasteAsPlainText: false,
                      autoParagraph: false,
                      fillEmptyBlocks: function (element) {
                      return true; //
                }
                });
                $('#ckEditorContainer').toggle();
                console.log('Replaced Editor');
          });
	      </script>
				<script src="/bower_components/ckeditor/ckeditor.js"></script>
			</cfsavecontent>
			<cfreturn htmlPage>
		</cffunction>



</cfcomponent>
