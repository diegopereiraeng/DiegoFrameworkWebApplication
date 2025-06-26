var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

var app = builder.Build();

// Configure the HTTP request pipeline.
// Enable serving static files from wwwroot
app.UseStaticFiles();

// Enable default file mapping (e.g., serve index.html for root path)
app.UseDefaultFiles();

app.MapGet("/", () => "Hello World! This is a fallback if index.html is not found.");

app.Run();
