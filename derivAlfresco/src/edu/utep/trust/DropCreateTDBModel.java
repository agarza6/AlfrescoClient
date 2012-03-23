package edu.utep.trust;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.List;

import org.alfresco.model.ContentModel;
import org.alfresco.service.cmr.repository.ChildAssociationRef;
import org.alfresco.service.cmr.repository.ContentReader;
import org.alfresco.service.cmr.repository.NodeRef;
import org.alfresco.service.cmr.repository.StoreRef;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.mindswap.pellet.jena.PelletReasonerFactory;
import org.springframework.extensions.webscripts.Container;
import org.springframework.extensions.webscripts.Description;
import org.springframework.extensions.webscripts.WebScriptRequest;
import org.springframework.extensions.webscripts.WebScriptResponse;

import com.hp.hpl.jena.query.QueryExecution;
import com.hp.hpl.jena.query.QueryExecutionFactory;
import com.hp.hpl.jena.query.ResultSet;
import com.hp.hpl.jena.rdf.model.InfModel;
import com.hp.hpl.jena.rdf.model.Model;
import com.hp.hpl.jena.rdf.model.ModelFactory;
import com.hp.hpl.jena.reasoner.Reasoner;
import com.hp.hpl.jena.tdb.TDBFactory;

public class DropCreateTDBModel extends DerivAbstractWebScript {

  public static final StoreRef SPACES_STORE = new StoreRef(StoreRef.PROTOCOL_WORKSPACE, "SpacesStore");
  public static final String XPATH_COMPANY_HOME = "/app:company_home";
  
  public static final String PARAM_ROOT_UUID = "rootUuid";

  protected Log logger = LogFactory.getLog(this.getClass());

  private Model pmlOntology;
  
  private String tdbLocation; 

  @Override
  public void init(Container container, Description description) {
    // TODO Auto-generated method stub
    super.init(container, description);

    System.out.println("init GetProvenance bean");
    // Cache external ontologies to speed up things
    this.pmlOntology = ModelFactory.createDefaultModel();
    pmlOntology.read("http://inference-web.org/2.0/pml-provenance.owl");
    pmlOntology.read("http://inference-web.org/2.0/pml-justification.owl");
  }

  @Override
  protected void executeImpl(WebScriptRequest req, WebScriptResponse res, File requestContent) throws Exception {
    try {
      File modelDirectory = new File(tdbLocation);
      // If it exists then clean it, else create it.
      if (modelDirectory.exists()) {
        for (File file : modelDirectory.listFiles()) {
          file.delete();
        }
      } else {
        modelDirectory.mkdir();
      }

      String rootUuid = req.getParameter(PARAM_ROOT_UUID);
      NodeRef rootNode = null;
      if (rootUuid != null) {
        rootNode = new NodeRef(SPACES_STORE, rootUuid);
      } else {
        rootNode = getNodeByXPath(XPATH_COMPANY_HOME);
      }

      Model model = TDBFactory.createModel(modelDirectory.getCanonicalPath());
      // Iterate through all files and load any pml data found
      recursivelyVisitNode(rootNode, model);
      String message = "model at " + tdbLocation + " has " + model.size() + " statements";
      System.out.println(message);
      model.close();

      res.getOutputStream().write(message.getBytes());
    } finally {
      if (res.getOutputStream() != null) {
        res.getOutputStream().close();
      }
    }
  }

  private void recursivelyVisitNode(NodeRef nodeRef, Model model) {
    if (nodeService.getType(nodeRef).equals(ContentModel.TYPE_CONTENT)) {
      // if containsRdf
      // AND if validate(file)
      // then model.read( new FileInputStream(it), null )
      if (containsRdf(nodeRef) && validate(nodeRef)) {
        ContentReader contentReader = contentService.getReader(nodeRef, ContentModel.PROP_CONTENT);
        model.read(contentReader.getContentInputStream(), null);
      }
    }

    List<ChildAssociationRef> children = nodeService.getChildAssocs(nodeRef);
    for (ChildAssociationRef childAssoc : children) {
      recursivelyVisitNode(childAssoc.getChildRef(), model);
    }

  }

  private boolean containsRdf(NodeRef nodeRef) {
    // if the file's contents contains "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    ContentReader contentReader = contentService.getReader(nodeRef, ContentModel.PROP_CONTENT);
    // The reader may be null, e.g. for folders and the like
    if (contentReader == null || contentReader.getMimetype() == null) {
      // No content to extract data from
      return false;
    }
    BufferedReader reader = null;
    try {
      String encoding = contentReader.getEncoding();
      // create a reader from the input stream
      if (encoding == null) {
        reader = new BufferedReader(new InputStreamReader(contentReader.getContentInputStream()));
      } else {
        reader = new BufferedReader(new InputStreamReader(contentReader.getContentInputStream(), encoding));
      }
      String line = reader.readLine();
      while (line != null) {
        line = reader.readLine();
        if (line.contains("http://www.w3.org/1999/02/22-rdf-syntax-ns#")) {
          return true;
        }
      }

    } catch (Exception e) {
      logger.error("Failed ", e);
      return false;
    } finally {
      if (reader != null) {
        try {
          reader.close();
        } catch (Exception ex) {
          logger.error("failed closing stream", ex);
        }
      }
    }
    return false;
  }

  // private boolean validate(File file) {
  private boolean validate(NodeRef nodeRef) {
    ContentReader contentReader = contentService.getReader(nodeRef, ContentModel.PROP_CONTENT);
    // The reader may be null, e.g. for folders and the like
    if (contentReader == null || contentReader.getMimetype() == null) {
      // No content to extract data from
      return false;
    }

    try {
      Model model;
      model = ModelFactory.createDefaultModel();
      model.add(pmlOntology);
      model.read(contentReader.getContentInputStream(), null);

      // Create a Pellet inference model.
      Reasoner reasoner = PelletReasonerFactory.theInstance().create();
      InfModel infModel = ModelFactory.createInfModel(reasoner, model);

      // Now run a sample SPARQL query against it. If we don't get an error, then all is well.
      String query = "SELECT ?a ?b ?c WHERE {?a ?b ?c.}";
      QueryExecution qe = QueryExecutionFactory.create(query, infModel);
      ResultSet rs = qe.execSelect();
      return true;
    } catch (Throwable e) {
      e.printStackTrace();
      return false;
    }
  }
  
  public void setTdbLocation(String newLocation){
    this.tdbLocation = newLocation;
  }

  private NodeRef getNodeByXPath(String path){
    NodeRef ret = null;

    // do NOT use a Lucene query because it gets slower as the repository gets
    // bigger
    // lets see how well an xpath search does
    final NodeRef rootNodeRef = nodeService.getRootNode(SPACES_STORE);
    final List<NodeRef> results = searchService.selectNodes(rootNodeRef, path, null, namespaceService, false);
    if (results.size() > 0) {
      ret = results.get(0);
    }

    return ret;
  }
  
}
