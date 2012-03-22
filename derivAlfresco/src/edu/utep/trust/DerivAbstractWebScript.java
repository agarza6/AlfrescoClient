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

import javax.servlet.http.HttpServletResponse;

import org.alfresco.repo.security.authentication.AuthenticationComponent;
import org.alfresco.repo.security.permissions.AccessDeniedException;
import org.alfresco.repo.transaction.RetryingTransactionHelper.RetryingTransactionCallback;
import org.alfresco.service.cmr.repository.ContentService;
import org.alfresco.service.cmr.repository.CopyService;
import org.alfresco.service.cmr.repository.MimetypeService;
import org.alfresco.service.cmr.repository.NodeService;
import org.alfresco.service.cmr.search.SearchService;
import org.alfresco.service.cmr.security.AuthorityService;
import org.alfresco.service.cmr.security.OwnableService;
import org.alfresco.service.cmr.security.PermissionService;
import org.alfresco.service.namespace.NamespaceService;
import org.alfresco.service.transaction.TransactionService;
import org.alfresco.util.TempFileProvider;
import org.springframework.extensions.webscripts.AbstractWebScript;
import org.springframework.extensions.webscripts.WebScriptRequest;
import org.springframework.extensions.webscripts.WebScriptResponse;
import org.springframework.util.FileCopyUtils;

public abstract class DerivAbstractWebScript extends AbstractWebScript {

  protected NodeService nodeService;
  protected ContentService contentService;
  protected SearchService searchService;
  protected NamespaceService namespaceService;
  protected MimetypeService mimetypeService;
  protected TransactionService transactionService;
  protected CopyService copyService;
  protected AuthorityService authorityService;
  protected PermissionService permissionService;
  protected OwnableService ownableService;
  protected AuthenticationComponent authenticationComponent;
  
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
          executeImpl(req, res, requestContent);

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
    transactionService.getRetryingTransactionHelper().doInTransaction(callback, false);

    // Now clean up our temp file
    requestContent.delete();
  }

  public void setMimetypeService(MimetypeService mimetypeService) {
    this.mimetypeService = mimetypeService;
  }

  public void setNodeService(NodeService nodeService) {
    this.nodeService = nodeService;
  }

  public void setContentService(ContentService contentService) {
    this.contentService = contentService;
  }

  public void setSearchService(SearchService searchService) {
    this.searchService = searchService;
  }

  public void setNamespaceService(NamespaceService namespaceService) {
    this.namespaceService = namespaceService;
  }

  public void setTransactionService(TransactionService transactionService) {
    this.transactionService = transactionService;
  }
  
  public void setCopyService(CopyService copyService) {
    this.copyService = copyService;
  }

  public void setAuthorityService(AuthorityService authorityService) {
    this.authorityService = authorityService;
  }

  public void setPermissionService(PermissionService permissionService) {
    this.permissionService = permissionService;
  }

  protected abstract void executeImpl(WebScriptRequest req, WebScriptResponse res, File requestContent) throws Exception;

  public void setOwnableService(OwnableService ownableService) {
    this.ownableService = ownableService;
  }

  public void setAuthenticationComponent(AuthenticationComponent authenticationComponent) {
    this.authenticationComponent = authenticationComponent;
  }

}
