<%@ page import="java.sql.*" %>
<%@ include file="includes/db.jsp" %>
<%
try {
    PreparedStatement ps = con.prepareStatement("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='ventas'");
    ResultSet rs = ps.executeQuery();
    out.println("<h3>Ventas columns:</h3>");
    while (rs.next()) {
        out.println(rs.getString("column_name") + " (" + rs.getString("data_type") + ")<br/>");
    }
    rs.close(); ps.close();

    ps = con.prepareStatement("SELECT column_name, data_type FROM information_schema.columns WHERE table_name='venta_detalle'");
    rs = ps.executeQuery();
    out.println("<h3>Venta_detalle columns:</h3>");
    while (rs.next()) {
        out.println(rs.getString("column_name") + " (" + rs.getString("data_type") + ")<br/>");
    }
    rs.close(); ps.close();
} catch(Exception e) {
    out.println("Error: " + e.getMessage());
}
%>
<%@ include file="includes/db_close.jsp" %>
