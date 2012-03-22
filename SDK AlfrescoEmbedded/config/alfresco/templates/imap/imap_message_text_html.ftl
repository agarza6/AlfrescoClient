<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
   <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">   
   <meta name="Generator" content="Alfresco Repository">

   <style type="text/css">
      body {
         background-color:#FFFFFF;
         color:#000000;
      }
      * {
         font-family:Verdana,Arial,sans-serif;
         font-size:11px;
      }
      h1 {
         text-align:left;
         font-size:15px;
      }
      h2 {
         text-align:left;
         font-size:13px;
      }
      fieldset {
         border:1px dotted #555555;
         margin:15px 5px 15px 5px;
      }
      fieldset legend {
         font-weight:bold;
         border:1px dotted #555555;
         background-color: #FFFFFF;
         padding:7px;
      }
      .links {
         border:0;
         border-collapse:collapse;
         width:99%;
      }
      .links td {
         border:0;
         padding:5px;
      }
      .description {
         border:0;
         border-collapse:collapse;
         width:99%;
      }
      .description td {
         /*border:1px dotted #555555;*/
         padding:5px;
      }
      #start_workflow input, #start_workflow select, #start_workflow textarea
      {
         border:1px solid #555555;
      }
   </style>
</head>
<body>
<hr/>
<h1> Document (name):   ${document.name} </h1>
<hr/>
<fieldset>
<legend> Metadata </legend>
<table class="description">
   <#if document.properties.title?exists>
                     <tr><td valign="top">Title:</td><td>${document.properties.title}</td></tr>
   <#else>
                     <tr><td valign="top">Title:</td><td>&nbsp;</td></tr>
   </#if>
   <#if document.properties.description?exists>
                     <tr><td valign="top">Description:</td><td>${document.properties.description}</td></tr>
   <#else>
                     <tr><td valign="top">Description:</td><td>&nbsp;</td></tr>
   </#if>
                     <tr><td>Creator:</td><td>${document.properties.creator}</td></tr>
                     <tr><td>Created:</td><td>${document.properties.created?datetime}</td></tr>
                     <tr><td>Modifier:</td><td>${document.properties.modifier}</td></tr>
                     <tr><td>Modified:</td><td>${document.properties.modified?datetime}</td></tr>
                     <tr><td>Size:</td><td>${document.size / 1024} Kb</td></tr>
</table>
</fieldset>
<fieldset>
<legend> Content links </legend>
<table class="links">
   <tr>
   <td>Content folder:</td><td><a href="${contextUrl}/navigate/browse${document.parent.webdavUrl}">${contextUrl}/navigate/browse${document.parent.webdavUrl}</a></td>
   </tr>
   <tr>
   <td>Content URL:</td><td><a href="${contextUrl}${document.url}">${contextUrl}${document.url}</a></td>
   </tr>
   <tr>
   <td>Download URL:</td><td><a href="${contextUrl}${document.downloadUrl}">${contextUrl}${document.downloadUrl}</a></td>
   </tr>
   <tr>
   <td>WebDAV URL:</td><td><a href="${contextUrl}${document.webdavUrl}">${contextUrl}${document.webdavUrl}</a></td>
   </tr>
</table>
</fieldset>
</body>
</html>