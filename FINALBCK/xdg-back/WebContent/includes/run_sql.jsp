<%@ page import="java.sql.*" %>
<%@ include file="db.jsp" %>
<%
try {
    PreparedStatement ps = con.prepareStatement("SELECT * FROM juegos WHERE id = 62");
    ResultSet rs = ps.executeQuery();
    if(rs.next()) {
        out.println("juego_id: " + rs.getInt("id") + ", precio: " + rs.getDouble("precio"));
    }
} catch(Exception e) {
    out.print("Error: " + e.getMessage());
}
%>
<%@ include file="db_close.jsp" %>
