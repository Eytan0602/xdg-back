﻿<%@ page contentType="application/json;charset=UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ include file="../includes/cors.jsp" %>
<%@ include file="../includes/db.jsp" %>
<%
String id      = (String) session.getAttribute("user_id");
String name    = (String) session.getAttribute("user_name");
String role    = (String) session.getAttribute("user_role");
String subRole = (String) session.getAttribute("user_sub_role");

if(id != null){
    String usuario = "";
    String correo  = "";
    try {
        PreparedStatement ps = con.prepareStatement("SELECT usuario, correo FROM usuarios WHERE id = ?");
        ps.setString(1, id);
        ResultSet rs = ps.executeQuery();
        if(rs.next()) {
            usuario = rs.getString("usuario");
            correo  = rs.getString("correo");
        }
        rs.close(); ps.close();
    } catch(Exception e) {}

    out.print("{");
    out.print("\"logged\":true,");
    out.print("\"id\":\"" + id + "\",");
    out.print("\"name\":\"" + name + "\",");
    out.print("\"username\":\"" + (usuario != null ? usuario : "") + "\",");
    out.print("\"email\":\"" + (correo != null ? correo : "") + "\",");
    out.print("\"role\":\"" + (role != null ? role : "user") + "\"");
    if(subRole != null) {
        out.print(",\"sub_role\":\"" + subRole + "\"");
    }
    out.print("}");
} else {
    out.print("{\"logged\":false}");
}
%>

<%@ include file="../includes/db_close.jsp" %>
