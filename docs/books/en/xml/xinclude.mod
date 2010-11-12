<!--
   Contains element declaration for XInclude
   See specification http://www.w3.org/TR/xinclude/
   
   $Id:$
-->

<!ENTITY % xmlnsxi 'xmlns:xi CDATA       #FIXED "http://www.w3.org/2001/XInclude"'>

<!ELEMENT xi:include (xi:fallback?) >
<!ATTLIST xi:include 
            %xmlnsxi;
            href            CDATA       #REQUIRED
            parse           (text|xml)  "xml"
            xpointer        CDATA       #IMPLIED
            encoding        CDATA       #IMPLIED
            accept          CDATA       #IMPLIED
            accept-charset  CDATA       #IMPLIED
            accept-language CDATA       #IMPLIED
            >
            
<!ELEMENT xi:fallback ANY >
<!ATTLIST xi:fallback %xmlnsxi; >
