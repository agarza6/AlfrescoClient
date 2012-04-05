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

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;

import org.alfresco.model.ContentModel;
import org.alfresco.service.cmr.repository.ContentWriter;
import org.alfresco.service.cmr.repository.NodeRef;
import org.alfresco.service.cmr.repository.StoreRef;
import org.springframework.extensions.webscripts.WebScriptRequest;
import org.springframework.extensions.webscripts.WebScriptResponse;

public class FileUploader extends DerivAbstractWebScript {

	static final String PARAM_UUID = "uuid";
	public static final StoreRef SPACES_STORE = new StoreRef(StoreRef.PROTOCOL_WORKSPACE, "SpacesStore");
	
	@Override
	protected Object executeImpl(WebScriptRequest req, WebScriptResponse res,
			File requestContent) throws Exception {
		
		String uuid = req.getParameter(PARAM_UUID);
		 
		NodeRef node = new NodeRef(SPACES_STORE, uuid);
		
		// Upload the image file
	    createFile(node, new FileInputStream(requestContent));
		return null;
	}

	public void createFile(final NodeRef node, final InputStream content) {
		 
	    // write some content to new node
	    final ContentWriter writer = contentService.getWriter(node, ContentModel.PROP_CONTENT, true);
	 
	    // guess the mime type
	    String name = (String)nodeService.getProperty(node, ContentModel.PROP_NAME);
	    final String guessedMimetype = mimetypeService.guessMimetype(name);
	    writer.setMimetype(guessedMimetype);
	    writer.putContent(content);
	  }
	
}
