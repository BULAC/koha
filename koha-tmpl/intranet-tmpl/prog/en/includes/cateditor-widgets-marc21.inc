<div id="editor-widget-templates" style="display:none">
    <div id="widget-leader">
        Leader:&nbsp;<span title="Record length (autogenerated)">#####</span>
        <select name="f5" title="Record status">
            <option value="a">a - Increase in encoding level</option>
            <option value="c">c - Corrected or revised</option>
            <option value="d">d - Deleted</option>
            <option value="n">n - New</option>
            <option value="p">p - Increase in encoding level from prepublication</option>
        </select>
        <select name="f6" title="Type of record">
            <option value="a">a - Language material</option>
            <option value="c">c - Notated music</option>
            <option value="d">d - Manuscript notated music</option>
            <option value="e">e - Cartographic material</option>
            <option value="f">f - Manuscript cartographic material</option>
            <option value="g">g - Projected medium</option>
            <option value="i">i - Nonmusical sound recording</option>
            <option value="j">j - Musical sound recording</option>
            <option value="k">k - Two-dimensional nonprojectable graphic</option>
            <option value="m">m - Computer file</option>
            <option value="o">o - Kit</option>
            <option value="p">p - Mixed materials</option>
            <option value="r">r - Three-dimensional artifact or naturally occurring object</option>
            <option value="t">t - Manuscript language material</option>
        </select>
        <select name="f7" title="Bibliographic level">
            <option value="a">a - Monographic component part</option>
            <option value="b">b - Serial component part</option>
            <option value="c">c - Collection</option>
            <option value="d">d - Subunit</option>
            <option value="i">i - Integrating resource</option>
            <option value="m">m - Monograph/item</option>
            <option value="s">s - Serial</option>
        </select>
        <select name="f8" title="Type of control">
                <option value=" ">_ - No specific type</option>
                <option value="a">a - Archival</option>
        </select>
        <span title="Encoding (forced Unicode)">a</span>
        <span title="Indicator/subfield lengths">22</span>
        <span title="Data base address (autogenerated)">#####</span>
        <select name="f17" title="Encoding level">
            <option value=" ">_ - Full level</option>
            <option value="1">1 - Full level, material not examined</option>
            <option value="2">2 - Less-than-full level, material not examined</option>
            <option value="3">3 - Abbreviated level</option>
            <option value="4">4 - Core level</option>
            <option value="5">5 - Partial (preliminary) level</option>
            <option value="7">7 - Minimal level</option>
            <option value="8">8 - Prepublication level</option>
            <option value="u">u - Unknown</option>
            <option value="z">z - Not applicable</option>
        </select>
        <select name="f18" title="Descriptive cataloging form">
            <option value=" ">_ - Non-ISBD</option>
            <option value="a">a - AACR 2</option>
            <option value="c">c - ISBD punctuation omitted</option>
            <option value="i">i - ISBD punctuation included</option>
            <option value="u">u - Unknown</option>
        </select>
        <select name="f19" title="Multipart record resource level">
            <option value=" ">_ - Not specified or not applicable</option>
            <option value="a">a - Set</option>
            <option value="b">b - Part with independent title</option>
            <option value="c">c - Part with dependent title</option>
        </select>
        <span title="Length of directory elements">4500</span>
    </div>
</div>

<script>

/**
 * Each widget should provide one to three methods:
 *   init( text ): Returns the DOM node for this widget.
 *   postCreate( node, mark ): Optional, called once the mark has been created
 *                             and the node shown. Bind event handlers here.
 *   makeTemplate(): Optional, should return some sane default contents for a
 *                   newly created field/subfield. '<empty>' will be used if this
 *                   method is unset.
 *
 * Following the Koha convention, control fields are defined as tags with a
 * single subfield, '@'.
 */

require( [ 'widget' ], function( Widget ) {
    Widget.Register( '000@', {
        makeTemplate: function() {
            return '     nam a22     7a 4500';
        },
        init: function() {
            var $result = $( '<span class="subfield-widget fixed-widget"></span>' );

            return $result[0];
        },
        postCreate: function() {
            // Clear the length and directory start fields; these are unnecessary for MARCXML and will be filled in upon USMARC export
            this.setFixed( 0, 5, '     ' );
            this.setFixed( 9, 17, 'a22     ' );
            this.setFixed( 20, 24, '4500' );

            this.insertTemplate( '#widget-leader' );

            this.bindFixed( '[name=f5]', 5, 6 );
            this.bindFixed( '[name=f6]', 6, 7 );
            this.bindFixed( '[name=f7]', 7, 8 );
            this.bindFixed( '[name=f8]', 8, 9 );
            this.bindFixed( '[name=f17]', 17, 18 );
            this.bindFixed( '[name=f18]', 18, 19 );
            this.bindFixed( '[name=f19]', 19, 20 );
        },
    } );

    Widget.Register( '005@', {
        init: function() {
            var $result = $( '<span class="subfield-widget fixed-widget">' + _("Updated: ") + '</span>' );

            return $result[0];
        },
        postCreate: function( node, mark ) {
            var parts = this.text.match( /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\.(\d)/ );

            if ( parts ) {
                var dateVal = new Date(
                    parseInt( parts[1] ), // Year
                    parseInt( parts[2] ) - 1, // Month (0-11)
                    parseInt( parts[3] ), // Day
                    parseInt( parts[4] ), // Hour
                    parseInt( parts[5] ), // Minute
                    parseInt( parts[6] ), // Second
                    parseInt( parts[7] ) * 100 // Millisecond
                );

                $( this.node ).append( dateVal.toLocaleString() );
            } else {
                $( this.node ).append( '<span class="hint">' + _("unset") + '</span>' );
            }
        }
    } );

    Widget.Register( '008@', {
        makeTemplate: function() {
            var now = new Date();
            return Widget.PadNum( now.getYear() % 100, 2 ) + Widget.PadNum( now.getMonth() + 1, 2 ) + Widget.PadNum( now.getDate(), 2 ) + "b        xxu||||| |||| 00| 0 [% DefaultLanguageField008 %] d";
        },
        init: function() {
            var $result = $( '<span class="subfield-widget fixed-widget">' + _("Fixed data:") + '<span class="hint widget-loading">' + _("Loading...") + '</span></span>' );

            return $result[0];
        },
        postCreate: function( node, mark ) {
            this.createFromXML( 'marc21/xml/008' );
        }
    } );
} );

</script>