<%@ page import="java.sql.*" %>

<%
Connection con = (Connection) application.getAttribute("DB_CONN");

try {

    if(con == null || con.isClosed()) {

        Class.forName("com.mysql.jdbc.Driver");

        con = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/tienda_juegos2?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true",
            "root",
            "123456789"
        );

        application.setAttribute("DB_CONN", con);
    }

} catch(Exception e) {
    out.print("{\"error\":\"DB connection failed: " + e.getMessage() + "\"}");
}
%>