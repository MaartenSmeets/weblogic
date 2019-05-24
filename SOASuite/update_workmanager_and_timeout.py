import wlstModule
from com.bea.wli.sb.management.configuration import SessionManagementMBean
from com.bea.wli.sb.management.query import BusinessServiceQuery
from com.bea.wli.sb.management.configuration import ALSBConfigurationMBean
from com.bea.wli.sb.management.configuration import ServiceConfigurationMBean
import inspect
import re
import traceback
from org.apache.xmlbeans import XmlObject
from org.apache.xmlbeans import XmlCursor
from org.apache.xmlbeans import XmlException
from org.apache.xmlbeans import XmlOptions
from javax.xml.namespace import QName

username='weblogic'
password='welcome1'
url='t3://localhost:7001'
connect(username,password,url)

def getServiceBusTarget():
    myTree=currentTree()
    serverConfig()
    cd('AppDeployments')
    cd('ALSB Resource')
    cd('Targets')
    res=ls(returnMap='true')[0]
    cd(res)
    print ('Service Bus determined to be running on: '+str(res)+' based on ALSB Resource targets')
    try:
        cmo.getClusterType()
        targetType='cluster'
    except AttributeError:
        targetType='server'
    print ('This is a: '+targetType)
    if targetType=='cluster':
        target='com.bea:Name='+res+',Type=Cluster'
    else:
        target='com.bea:Name='+res+',Type=Server'
    myTree()
    return res,target

def createThreadConstraint(tcName,target):
    myTree=currentTree()
    edit()
    startEdit()
    cd('/SelfTuning/'+domainName)
    try:
        cmo.createMinThreadsConstraint(tcName)
        cd('/SelfTuning/'+domainName+'/MinThreadsConstraints/'+tcName)
        set('Targets',jarray.array([ObjectName(target)], ObjectName))
        cmo.setCount(1)
        print(tcName+" created on: "+target)
        save()
        activate()
    except weblogic.descriptor.BeanAlreadyExistsException:
        print(tcName+" already exists. Skipping creation")
        cancelEdit('y')
    myTree()
    return

def createWorkmanager(wmName,tcName,target):
    myTree=currentTree()
    edit()
    startEdit()
    cd('/SelfTuning/'+domainName)
    try:
        cmo.createWorkManager(wmName)
        cd('/SelfTuning/'+domainName+'/WorkManagers/'+wmName)
        set('Targets',jarray.array([ObjectName(target)], ObjectName))
        cmo.setMinThreadsConstraint(getMBean('/SelfTuning/'+domainName+'/MinThreadsConstraints/'+tcName))
        cmo.setIgnoreStuckThreads(false)
        save()
        activate()
        print(wmName+" created")
    except weblogic.descriptor.BeanAlreadyExistsException:
        print(wmName+" already exists. Skipping creation")
        cancelEdit('y')
    myTree()
    return

#Below function creates the thread constraint and workmanager for the specified server
def createTCandWM():
    myTree=currentTree()
    basename,target=getServiceBusTarget()
    tcName=basename+'ResponseMinThreadsConstraint'
    wmName=basename+'ResponseWorkmanager'
    print ('Requesting ThreadsConstraint: '+tcName+' on target '+target)
    createThreadConstraint(tcName,target)
    createWorkmanager(wmName,tcName,target)
    myTree()
    return wmName

domainRuntime()
sessionMBean = findService(SessionManagementMBean.NAME, SessionManagementMBean.TYPE)
sessionName = "mysession"

try:
    sessionMBean.discardSession(sessionName)
    print ('Existing session found. Discarded')
except java.lang.IllegalArgumentException:
    print ('Session not found')

sessionMBean.createSession(sessionName)
#print(inspect.getmembers(sessionMBean))
bsQuery = BusinessServiceQuery()
alsbSession = findService(ALSBConfigurationMBean.NAME + "." + sessionName, ALSBConfigurationMBean.TYPE)
#print (inspect.getmembers(alsbSession))
#print ('ALSB session created: '+alsbSession)
refs = alsbSession.getRefs(bsQuery)

#11g. For 12.2.1.2 see "OSB 12.2.1.2, using MBean com.bea.wli.sb.services.ServiceDefinition serviceDef =serviceConfigMBean.getServiceDefinition(bsRef) (Doc ID 2305204.1)"
servConfMBean = findService(ServiceConfigurationMBean.NAME + "." + sessionName, ServiceConfigurationMBean.TYPE)
namePattern = "com.bea:Name=" + str(ServiceConfigurationMBean.NAME) + "." + str(sessionName) + ",Type=" + str(ServiceConfigurationMBean.TYPE)
objName = mbs.queryNames(ObjectName(namePattern), None)[0]

#use below for determining server
wmName=createTCandWM()
print ('Workmanager to use: '+wmName)

configMB = JMX.newMBeanProxy(mbs, objName, Class.forName(ServiceConfigurationMBean.TYPE))

#below displays the XML
#print(serviceDefinition)
#Inspiration from: https://medium.com/the-server-labs/alsb-osb-customization-using-wlst-193e980bea93
nsEnv = "declare namespace env='http://www.bea.com/wli/config/env' "
nsSer = "declare namespace ser='http://www.bea.com/wli/sb/services' "
nsTran = "declare namespace tran='http://www.bea.com/wli/sb/transports' "
nsHttp = "declare namespace http='http://www.bea.com/wli/sb/transports/http' "
nsIWay = "declare namespace iway='http://www.iwaysoftware.com/alsb/transports' "
confPathTimeout = "ser:endpointConfig/tran:provider-specific/http:outbound-properties/http:timeout"
confPathConnTimeout = "ser:endpointConfig/tran:provider-specific/http:outbound-properties/http:connection-timeout"
confPathDispatchPolicy = "ser:endpointConfig/tran:provider-specific/http:dispatch-policy"
#timeout values based on: https://oraclemiddlwaretips.wordpress.com/2015/08/29/hello-world/
confValueTimeout = "120"
confValueConnTimeout = "10"
confValueDispatchPolicy = wmName

def setServiceDefinitionValueUpdate(confElem,confValue,override):
    try:
        curVal=confElem.getStringValue()
        print ('Current value: '+str(curVal))
    except:
        curVal=''
    if (override == 'yes') or (override == 'no' and curVal == ''):
        confElem.setStringValue(confValue)
        return 'updated'
    else:
        return 'not updated'

#for adding since specific logic is required to determine the location where fields need to be added this needed to be manually coded
def addTimeout(serviceDefinition,confValueTimeout):
    try:
        cur=serviceDefinition.newCursor();
        #I do not have the XSD but it should go below the request method
        cur.selectPath(nsSer + nsTran + nsHttp + 'ser:endpointConfig/tran:provider-specific/http:outbound-properties/http:request-method')
        if cur.hasNextSelection:
            cur.toNextSelection()
            cur.toNextSibling()
            timeout = QName('http://www.bea.com/wli/sb/transports/http','timeout','http')
            cur.insertElementWithText(timeout,confValueTimeout)
        else:
            print ('No http transport')
        cur.dispose()
        return serviceDefinition
    except:
        print ('An error occurred')
        traceback.print_exc()
        cur.dispose()
        return serviceDefinition

def addConnTimeout(serviceDefinition,confValueConnTimeout):
    try:
        cur=serviceDefinition.newCursor();
        #I do not have the XSD but it should go below the request method
        cur.selectPath(nsSer + nsTran + nsHttp + 'ser:endpointConfig/tran:provider-specific/http:outbound-properties/http:timeout')
        if cur.hasNextSelection:
            cur.toNextSelection()
            cur.toNextSibling()
            conntimeout = QName('http://www.bea.com/wli/sb/transports/http','connection-timeout','http')
            cur.insertElementWithText(conntimeout,confValueConnTimeout)
        else:
            print ('No http transport')
        cur.dispose()
        return serviceDefinition
    except:
        print ('An error occurred')
        traceback.print_exc()
        cur.dispose()
        return serviceDefinition

def addDispatchPolicy(serviceDefinition,confValueDispatchPolicy):
    try:
        cur=serviceDefinition.newCursor();
        #I do not have the XSD but it should go after outbound-properties
        cur.selectPath(nsSer + nsTran + nsHttp + 'ser:endpointConfig/tran:provider-specific/http:outbound-properties')
        if cur.hasNextSelection:
            cur.toNextSelection()
            cur.toEndToken()
            cur.toNextToken()
            dispatchpolicy = QName('http://www.bea.com/wli/sb/transports/http','dispatch-policy','http')
            cur.insertElementWithText(dispatchpolicy,confValueDispatchPolicy)
        else:
            print ('No http transport')
        cur.dispose()
        return serviceDefinition
    except:
        print ('An error occurred')
        traceback.print_exc()
        cur.dispose()
        return serviceDefinition

def updateBS(bsRef):
    serviceDefinition = configMB.getServiceDefinition(bsRef)
    #Print class: print (str(serviceDefinition.__class__.__name__)) result: com.bea.wli.sb.services.impl.ServiceDefinitionImpl
    #Finding a class in jars: grep ServiceDefinitionImpl `find . -name '*.jar'`
    #after decompile servicedefinition extends: https://xmlbeans.apache.org/docs/2.0.0/reference/org/apache/xmlbeans/XmlObject.html
    #domNode=serviceDefinition.getDomNode()
    #this is: https://www.w3.org/2003/01/dom2-javadoc/org/w3c/dom/Node.html
    #alternative is: https://stackoverflow.com/questions/2519804/how-to-add-a-node-to-xml-with-xmlbeans-xmlobject
    print ('Configuring timeout')
    try:
        confElemPathTimeout = serviceDefinition.selectPath(nsSer + nsTran + nsHttp + confPathTimeout)[0]
        result=setServiceDefinitionValueUpdate(confElemPathTimeout,confValueTimeout,'no')
    except IndexError:
        print ('Timeout setting not found. Adding')
        serviceDefinition==addTimeout(serviceDefinition,confValueTimeout)
        result = 'OK'

    print (result)
    
    print ('Configuring connection timeout')
    try:
        confElemPathConnTimeout = serviceDefinition.selectPath(nsSer + nsTran + nsHttp + confPathConnTimeout)[0]
        result=setServiceDefinitionValueUpdate(confElemPathConnTimeout,confValueConnTimeout,'no')
    except IndexError:
        print ('Connection Timeout setting not found. Adding')
        result=addConnTimeout(serviceDefinition,confValueConnTimeout)
    
    print (result)
    try:
        print ('Configuring Dispatch policy')
        confElemPathDispatchPolicy = serviceDefinition.selectPath(nsSer + nsTran + nsHttp + confPathDispatchPolicy)[0]
        result=setServiceDefinitionValueUpdate(confElemPathDispatchPolicy,confValueDispatchPolicy,'no')
    except IndexError:
        print('Dispatch policy not found. Adding')
        result=addDispatchPolicy(serviceDefinition,confValueDispatchPolicy)
    print (result)
    #print (str(serviceDefinition))
    configMB.updateService(bsRef, serviceDefinition)
    return 'done'

try:
    for bsRef in refs:
        print ('Start processing: '+str(bsRef))
        result=updateBS(bsRef)
        print (result)
except java.util.NoSuchElementException:
    print ('No business services found')
except:
    print ('Discarding session because unexpected error')
    traceback.print_exc()
    sessionMBean.discardSession(sessionName)
else:
    print('Activating session because done without errors')
    sessionMBean.activateSession(sessionName,'Done with updating timeouts connection timeouts and workmanager')

#should [ConfigFwk:390105]Unable to create WLS change list due to a short term automatic lock obtained by user weblogic. The user has no pending changes and the lock will expire in -1.311.836.889 seconds. Please try again after the lock has expired. occur: check solution at https://www.orienteit.nl/osb-automatic-lock-issue-configfwk390105/
