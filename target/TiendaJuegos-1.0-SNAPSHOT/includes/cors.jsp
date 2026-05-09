<%
String origin = request.getHeader("Origin");
if(origin != null) {
    response.setHeader("Access-Control-Allow-Origin", origin);
} else {
    response.setHeader("Access-Control-Allow-Origin", "*");
}
response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
response.setHeader("Access-Control-Allow-Headers", "Content-Type");
response.setHeader("Access-Control-Allow-Credentials", "true");
response.setContentType("application/json;charset=UTF-8");

if(request.getMethod().equals("OPTIONS")){
    response.setStatus(200);
    return;
}
%>