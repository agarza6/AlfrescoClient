package edu.utep.trust;

import java.io.File;
import java.io.IOException;

import org.springframework.beans.BeansException;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;
import org.springframework.context.ApplicationEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.extensions.webscripts.Container;
import org.springframework.extensions.webscripts.Description;
import org.springframework.extensions.webscripts.WebScriptRequest;
import org.springframework.extensions.webscripts.WebScriptResponse;

import com.hp.hpl.jena.query.QueryExecution;
import com.hp.hpl.jena.query.QueryExecutionFactory;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.query.ResultSetFormatter;
import com.hp.hpl.jena.rdf.model.InfModel;
import com.hp.hpl.jena.rdf.model.Model;
import com.hp.hpl.jena.rdf.model.ModelFactory;
import com.hp.hpl.jena.reasoner.Reasoner;
import com.hp.hpl.jena.reasoner.ReasonerRegistry;
import com.hp.hpl.jena.tdb.TDBFactory;

public class QueryRdfStore extends DerivAbstractWebScript implements ApplicationContextAware, ApplicationListener {
  private Model schema;
  
  private String tdbLocation;

  private Model model;

  private InfModel infModel;

  private Object applicationContext;
  
  public static final String PARAM_QUERY = "query";
  
  @Override
  public void init(Container container, Description description) {
    // TODO Auto-generated method stub
    super.init(container, description);

    System.out.println("init GetProvenance bean");
    // Cache external ontologies to speed up things
    this.schema = ModelFactory.createDefaultModel();
    //these are the owls read in while creating the triple store but it looks like a different (smaller) one
    //is used for queries:
    schema.read("http://trust.utep.edu/members/jarora/PML-SPARQL.owl");
//    pmlOntology.read("http://inference-web.org/2.0/pml-provenance.owl");
//    pmlOntology.read("http://inference-web.org/2.0/pml-justification.owl");
    
    File modelDirectory = new File(tdbLocation);
    try {
      this.model = TDBFactory.createModel(modelDirectory.getCanonicalPath());
    } catch (IOException e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    }
    
    Reasoner reasoner = ReasonerRegistry.getRDFSReasoner();
    this.infModel = ModelFactory.createInfModel( reasoner, schema, model );
  }
  
  @Override
  protected void executeImpl(WebScriptRequest req, WebScriptResponse res, File requestContent) throws Exception {
    try{
      String query = req.getParameter(PARAM_QUERY);//"SELECT ?person ?name WHERE {?person a <http://inference-web.org/2.0/pml-provenance.owl#Person> . ?person <http://inference-web.org/2.0/pml-provenance.owl#hasName> ?name .}";//
      if(query == null){
        res.getOutputStream().write("Error - no query string passed in".getBytes());
      }else{
        res.getOutputStream().write(doQuery(query).getBytes());
      }
    } finally {
      if (res.getOutputStream() != null) {
        res.getOutputStream().close();
      }
    }
  }
  
  
  public String doQuery(String query) {
    ResultSet rs = doQueryForResultSet(query);
    //TODO see if this can be streamed directly to the response instead
    return ResultSetFormatter.asXMLString(rs); 
  }
  
  private ResultSet doQueryForResultSet(String query) {
    QueryExecution qe = null;
    ResultSet rs = null;
    qe = QueryExecutionFactory.create( query, infModel );
    rs = qe.execSelect();
    return rs;
}
  
  
  public void onApplicationEvent(ApplicationEvent event)
  {
      if (event instanceof ContextClosedEvent)
      {
          ContextClosedEvent closedEvent = (ContextClosedEvent)event;
          ApplicationContext closedContext = closedEvent.getApplicationContext();
          if (closedContext != null && closedContext.equals(applicationContext))
          {
            model.close();
          }
      }
  }
  
  public void setTdbLocation(String newLocation){
    this.tdbLocation = newLocation;
  }

  @Override
  public void setApplicationContext(ApplicationContext arg0) throws BeansException {
    this.applicationContext = applicationContext;
  }
}
