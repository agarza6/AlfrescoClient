[
<#if results??>
<#list results as child>
    "${child.name}"<#if child_has_next>,</#if>
</#list>
</#if>
]