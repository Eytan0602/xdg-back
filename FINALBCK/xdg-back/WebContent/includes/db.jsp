<%@ page import="java.sql.*" %>

<%
Connection con = (Connection) application.getAttribute("DB_CONN");

try {

    if (con == null || con.isClosed()) {

        Class.forName("org.postgresql.Driver");

        con = DriverManager.getConnection(
            "jdbc:postgresql://aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require",
            "postgres.hvnplebbyprpzxygttdz",
            "QPEp35kdE6NkVjOJ"
        );

        application.setAttribute("DB_CONN", con);
    }

} catch(Exception e) {
    out.print("{\"error\":\"DB connection failed: " + e.getMessage().replace("\"", "'") + "\"}");
}
%>