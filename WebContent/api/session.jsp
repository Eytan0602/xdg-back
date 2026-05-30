﻿<%@ page contentType="application/json;charset=UTF-8" %>
<%@ include file="../includes/cors.jsp" %>
<%
String id = (String) session.getAttribute("user_id");
String name = (String) session.getAttribute("user_name");

if(id != null){
    out.print("{");
    out.print("\"logged\":true,");
    out.print("\"id\":\"" + id + "\",");
    out.print("\"name\":\"" + name + "\"");
    out.print("}");
} else {
    out.print("{\"logged\":false}");
}
%>