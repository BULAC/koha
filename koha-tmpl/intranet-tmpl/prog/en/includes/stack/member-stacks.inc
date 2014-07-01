<!-- B032 -->
<!-- TMPL_IF NAME="STACKS" -->
    <script type="text/javascript">
        
        $(document).ready(function() {
            
            $("#stackst").tablesorter({<!-- TMPL_IF NAME="dateformat_metric" -->
                dateFormat: 'uk',<!-- /TMPL_IF -->
                sortList: [[0,0]],
                headers: {1:{sorter:'articles'}, 8:{sorter:false}, 9:{sorter:false}}
            });
            
            var allcheckboxes = $(".stack_checkboxed");
            
            <!-- TMPL_IF NAME="AllowRenewalLimitOverride" -->
            $( '#stack_override_limit' ).click( function () {
                if ( this.checked ) {
                    $( '.stack_renewals_allowed' ).show();
                    $( '.stack_renewals_disabled' ).hide();
                } else {
                    $( '.stack_renewals_allowed' ).hide();
                    $( '.stack_renewals_disabled' ).show();
                    $(allcheckboxes).unCheckCheckboxes(":input[name=stack_renew]");
                }
            } ).attr( 'checked', false );
            <!-- /TMPL_IF -->
            
            $("#stack_check_all_renew").click(function(){
                $(allcheckboxes).checkCheckboxes(":input[name=stack_renew]:visible");
                $(allcheckboxes).unCheckCheckboxes(":input[name=stack_cancel]");
                return false;
            });
            $("#stack_check_none_renew").click(function(){
                $(allcheckboxes).unCheckCheckboxes(":input[name=stack_renew]");
                return false;
            });
            $("#stack_check_all_cancel").click(function(){
                $(allcheckboxes).checkCheckboxes(":input[name=stack_cancel]:visible");
                $(allcheckboxes).unCheckCheckboxes(":input[name=stack_renew]");
                return false;
            });
            $("#stack_check_none_cancel").click(function(){
                $(allcheckboxes).unCheckCheckboxes(":input[name=stack_cancel]");
                return false;
            });
        });
        
        function RenewStacksOfBorrower(cform) {
            var chk = $(cform).find(":input[name=stack_renew]:checked");
            if (chk.length == 0) {
                return false;
            }
        }
        
        function CancelStacksOfBorrower(cform) {
            var chk = $(cform).find(":input[name=stack_cancel]:checked");
            if (chk.length == 0) {
                return false;
            } else if (cform.sortCancel.value == '') {
                alert(_("Please select a cancel cause."));
                return false;
            }
        }
        
        // uncheck input with the same value
        function uncheckOther(inp) {
            var othr = $("#stackst input[value=" + inp.value + "]");
            $(othr).not("input[name=" + inp.name + "]").attr('checked', false);
        }
    </script>
    
    <form action="/cgi-bin/koha/stack/renew-cancel-stacks.pl" method="post" class="stack_checkboxed">
    
    <input type="hidden" name="borrowernumber" value="<!-- TMPL_VAR NAME='borrowernumber' -->" />
    <input type="hidden" name="destination"    value="<!-- TMPL_VAR NAME='destination' -->" />
    
    <table id="stackst">
    <thead>
        <tr>
            <th scope="col">End</th>
            <th scope="col">Title</th>
            <th scope="col">Item Type</th>
            <th scope="col">Begin</th>
            <th scope="col">Call no</th>
            <th scope="col">Status</th>
            <th scope="col">Item State</th>
            <th scope="col">Id</th>
            <th scope="col">
                Renew
                <p class="column-tool">
                    <a href="#" id="stack_check_all_renew">select all</a> | <a href="#" id="stack_check_none_renew">none</a>
                </p>
            </th>
            <th scope="col">
                Cancel
                <p class="column-tool">
                    <a href="#" id="stack_check_all_cancel">select all</a> | <a href="#" id="stack_check_none_cancel">none</a>
                </p>
            </th>
        </tr>
    </thead>
    <tbody>
    <!-- TMPL_LOOP name="STACKS" -->
        <tr>
            <!-- TMPL_IF NAME="od" --><td class="od"><!-- TMPL_ELSE --><td><!-- /TMPL_IF -->
                <!-- TMPL_VAR NAME="end_date_ui" -->
            </td>
            <td>
                <!-- TMPL_IF NAME="title" -->
                    <a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=<!-- TMPL_VAR NAME='biblionumber' -->">
                        <strong><!-- TMPL_VAR NAME="title" ESCAPE="HTML" --></strong>
                    </a>
                <!-- TMPL_ELSE -->
                    <strong><!-- TMPL_VAR NAME="nc_title" ESCAPE="HTML" --></strong>
                <!-- /TMPL_IF -->
                
                <!-- TMPL_IF NAME="author" -->
                    , by <!-- TMPL_VAR NAME="author" -->
                <!-- TMPL_ELSIF NAME="nc_author" -->
                    , by <!-- TMPL_VAR NAME="nc_author" ESCAPE="HTML" -->
                <!-- /TMPL_IF -->
                
                <!-- TMPL_IF NAME="publishercode" -->; <!-- TMPL_VAR NAME="publishercode" --> <!-- /TMPL_IF -->
                
                <!-- TMPL_IF NAME="publicationyear" -->
                    , <!-- TMPL_VAR NAME="publicationyear" -->
                <!-- TMPL_ELSIF NAME="nc_pubyear" -->
                    , <!-- TMPL_VAR NAME="nc_pubyear" ESCAPE="HTML" -->
                <!-- /TMPL_IF -->
                
                <!-- TMPL_IF NAME="itemnumber" -->
                    <a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=<!-- TMPL_VAR NAME='biblionumber' -->&amp;itemnumber=<!-- TMPL_VAR NAME='itemnumber' -->#item<!-- TMPL_VAR NAME='itemnumber' -->">
                        <!-- TMPL_VAR NAME="barcode" -->
                    </a>
                <!-- /TMPL_IF -->
            </td>
            <td><!-- TMPL_UNLESS NAME="noItemTypeImages" --> <!-- TMPL_IF NAME="itemtype_image" --><img src="<!-- TMPL_VAR NAME='itemtype_image' -->" alt="" /><!-- /TMPL_IF --><!-- /TMPL_UNLESS --><!-- TMPL_VAR NAME="itemtype_description" --></td>
            <td><!-- TMPL_VAR NAME="begin_date_ui" --></td>
            <td>
                <!-- TMPL_IF NAME="itemcallnumber" -->
                    <!-- TMPL_VAR NAME="itemcallnumber" ESCAPE="HTML" -->
                <!-- TMPL_ELSE -->
                    <!-- TMPL_VAR NAME="nc_callnumber" ESCAPE="HTML" -->
                <!-- /TMPL_IF -->
            </td>
            <td><!-- TMPL_INCLUDE NAME="stack/stack-state.inc" --></td>
            <td><!-- TMPL_LOOP NAME="items" --><!-- TMPL_INCLUDE NAME="istate-addon.inc" --><!-- /TMPL_LOOP --></td>
            <td>
                <a href="/cgi-bin/koha/stack/all-operations.pl?input=<!-- TMPL_VAR NAME='request_number' -->">
                    <!-- TMPL_VAR NAME="request_number" -->
                </a>
            </td>
            <td style="text-align:center;">
                <!-- TMPL_IF NAME="renewals" -->
                    <span><!-- TMPL_VAR NAME="renewals" --></span>
                <!-- /TMPL_IF -->
                <!-- TMPL_IF NAME="canRenew" -->
                    <span <!-- TMPL_IF NAME="renewMustConfirm" -->class="stack_renewals_allowed" style="display:none;"<!-- /TMPL_IF -->>
                        <input type="checkbox" name="stack_renew"  value="<!-- TMPL_VAR NAME='request_number' -->" onclick="uncheckOther(this);" />
                    </span>
                <!-- /TMPL_IF -->
                
                <!-- TMPL_IF NAME="renew_confirm" -->
                <!-- TMPL_LOOP NAME="renew_confirm" -->
                    <span class="stack_renewals_disabled">
                        <!-- TMPL_IF NAME="TOO_MANY_RENEWALS" -->Quota
                        <!-- TMPL_ELSIF NAME="TOO_MANY_RENEWAL_QTY" -->Quota
                        <!-- /TMPL_IF -->
                    </span>
                <!-- /TMPL_LOOP -->
                <!-- /TMPL_IF -->
                            
                <!-- TMPL_IF NAME="renew_impossible" -->
                <!-- TMPL_LOOP NAME="renew_impossible" -->
                    <span>
                        <!-- TMPL_IF NAME="CANCELED" -->Not Renewable
                        <!-- TMPL_ELSIF NAME="NOT_RUNNING" -->Not Renewable
                        <!-- TMPL_ELSIF NAME="ALREADY_RENEWED" -->Renewed
                        <!-- TMPL_ELSIF NAME="SPACE_BOOKING" -->For Space
                        <!-- TMPL_ELSIF NAME="ON_RESERVE" -->On Hold
                        <!-- TMPL_ELSIF NAME="BLOCKING_SR" -->Requested
                        <!-- TMPL_ELSIF NAME="NOT_IN_DESK" -->Not in desk
                        <!-- TMPL_ELSE -->Not Renewable
                        <!-- /TMPL_IF -->
                    </span>
                <!-- /TMPL_LOOP -->
                <!-- /TMPL_IF -->
            </td>
            <td style="text-align:center;">
                <!-- TMPL_IF NAME="canCancel" -->
                    <input type="checkbox" name="stack_cancel" value="<!-- TMPL_VAR NAME='request_number' -->" onclick="uncheckOther(this);" />
                <!-- TMPL_ELSE -->
                    Not Cancelable
                <!-- /TMPL_IF -->
            </td>
        </tr>
    <!-- /TMPL_LOOP -->
    </tbody>
    </table>
    
    <fieldset class="action">
        <div style="float:left;">
            <!-- TMPL_IF NAME="CAN_user_circulate_override_maxstackrenewalqty" -->
                <label for="stack_override_limit">Override Renewal Limit:</label>
                <input type="checkbox" name="stack_override_limit" id="stack_override_limit" value="1" />
            <!-- /TMPL_IF -->
        </div>
        <div style="float:right;text-align:right;">
            <div style="margin-bottom:.2em;">
                <input type="submit" name="stack_renew_checked" value="Renew checked items" onclick="return RenewStacksOfBorrower(this.form);" />
            </div>
            <div>
                Select a cause : <!-- TMPL_VAR NAME="CGIcancel" -->
                <input type="submit" name="stack_cancel_checked" value="Cancel checked items" onclick="return CancelStacksOfBorrower(this.form);" />
            </div>
        </div>
    </fieldset>
    
    </form>
    
<!-- TMPL_ELSE -->
    <p>Patron has no stack request.</p>
<!-- /TMPL_IF -->
<!-- END B032 -->