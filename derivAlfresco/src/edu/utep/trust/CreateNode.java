/**
Copyright (c) 2012, University of Texas at El Paso
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
DAMAGE.
 */

package edu.utep.trust;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.io.Serializable;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpServletResponse;

import org.alfresco.model.ContentModel;
import org.alfresco.repo.security.permissions.AccessDeniedException;
import org.alfresco.repo.transaction.RetryingTransactionHelper.RetryingTransactionCallback;
import org.alfresco.service.cmr.repository.NodeRef;
import org.alfresco.service.cmr.repository.StoreRef;
import org.alfresco.service.namespace.NamespaceService;
import org.alfresco.service.namespace.QName;
import org.alfresco.util.ISO9075;
import org.alfresco.util.TempFileProvider;
import org.alfresco.web.app.servlet.DownloadContentServlet;
import org.springframework.extensions.webscripts.WebScriptRequest;
import org.springframework.extensions.webscripts.WebScriptResponse;
import org.springframework.util.FileCopyUtils;

public class CreateNode extends DerivAbstractWebScript {

	static final String PARAM_PROJECT = "project";
	static final String PARAM_FILENAME = "filename";

	static final String XPATH_PROJECT = "/app:company_home/cm:Projects/cm:";

	public static final StoreRef SPACES_STORE = new StoreRef(StoreRef.PROTOCOL_WORKSPACE, "SpacesStore");

	@Override
	protected Object executeImpl(WebScriptRequest req, WebScriptResponse res,
			File requestContent) throws Exception {

		String project = req.getParameter(PARAM_PROJECT);
		String filename = req.getParameter(PARAM_FILENAME);

		String url = XPATH_PROJECT + ISO9075.encode(project);

		NodeRef pNode = getNodeByXPath(url);

		// Create the node properties
	    Map<QName, Serializable> properties = new HashMap<QName, Serializable>(1);
	    properties.put(ContentModel.PROP_NAME, filename);
		
		/**
		 * Parameter Description:
		 * parentRef - xpath + project name (node url)
		 * assocTypeQName - type of association between parent and new node
		 * assocQName - name of the association ("has a", "is a" etc)
		 * nodeTypeQName - type of node (content, user, etc)
		 * properties - node metadata.
		 */
		NodeRef newNode = nodeService.createNode(pNode, ContentModel.ASSOC_CONTAINS, QName.createQName(NamespaceService.CONTENT_MODEL_1_0_URI, filename), ContentModel.TYPE_CONTENT, properties).getChildRef();

		String URI = DownloadContentServlet.generateDownloadURL(newNode, filename);

		return URI;
	}
	
	 @Override
	  public void execute(final WebScriptRequest req, final WebScriptResponse res) throws IOException {
	    // First save the request content to a temporary file so we can reuse it in case of a retrying transaction
	    BufferedInputStream inputStream = new BufferedInputStream(req.getContent().getInputStream());
	    final File requestContent = TempFileProvider.createTempFile("cat_sdkdi", ".xml");
	    FileCopyUtils.copy(inputStream, new FileOutputStream(requestContent));    
	    
	    // Wrap in a retrying transaction handler in case of db deadlock
	    RetryingTransactionCallback<Object> callback = new RetryingTransactionCallback<Object>()
	    {
	      public Object execute() throws Exception
	      {

	        try {
	          String URI = (String)executeImpl(req, res, requestContent);

	        } catch (Exception e) {
	          if(e instanceof AccessDeniedException) {
	            res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
	          } else {
	            // throw it back for web script framework to handle
	            throw e;
	          }
	        }
	        return null;
	      }
	    };
	    String URI = (String)transactionService.getRetryingTransactionHelper().doInTransaction(callback, false);
	    PrintStream printStream = null;
	    try{
	      printStream = new PrintStream(res.getOutputStream(), true, "UTF-8");
	      printStream.println(URI);
	      printStream.flush();
	    } finally {
	      if(printStream != null) {
	        printStream.close();
	      }
	    }
	    // Now clean up our temp file
	    requestContent.delete();
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