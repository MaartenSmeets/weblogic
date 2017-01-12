package nl.amis.customfield;

//import java.io.PrintWriter;
//import java.io.StringWriter;

import org.apache.http.entity.ContentType;
import weblogic.servlet.logging.CustomELFLogger;
import weblogic.servlet.logging.FormatStringBuffer;
import weblogic.servlet.logging.HttpAccountingInfo;


public class SOAPActionField implements CustomELFLogger {
    public SOAPActionField() {
        super();
    }

    @Override
    public void logField(HttpAccountingInfo metrics, FormatStringBuffer buff) {
        String addthis = null;
        try {
            //first try SOAP 1.1 HTTP header SOAPAction
            //System.out.println("SOAPActionField: getHeader");
            String soapaction = metrics.getHeader("SOAPAction");
            if (soapaction != null) {
                soapaction = soapaction.replace("\"", "");
                if (soapaction.length() > 0) {
                    //System.out.println("SOAPActionField: SOAP 1.1 HTTP header SOAPAction: "+soapaction);
                    addthis = soapaction;
                }
            } else {
                //next try SOAP 1.2 Content-Type parameter action
                //System.out.println("SOAPActionField: getContentType");
                String contenttypestr = metrics.getContentType();
                //System.out.println("SOAPActionField: getContentType result: "+contenttypestr);
                ContentType mycontenttype = ContentType.parse(contenttypestr);
                //System.out.println("SOAPActionField: ContentType parsed");
                String action = mycontenttype.getParameter("action");
                //System.out.println("SOAPActionField: ContentType action parameter obtained: "+action);
                if (action != null && action.length()>0) {
                    //System.out.println("SOAPActionField: SOAP 1.2 HTTP header Content-Type parameter action: "+action);
                    addthis = action;
                }
            }
        } catch (Exception e) {
            //StringWriter sw = new StringWriter();
            //PrintWriter pw = new PrintWriter(sw);
            //e.printStackTrace(pw);
            //System.out.println("SOAPActionField: "+sw.toString());
            addthis = null;
        }
        //System.out.println("SOAPActionField: Returning: "+addthis);
        buff.appendValueOrDash(addthis);
    }
}
