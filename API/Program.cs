using API.Settings;
using EventWithMongo.Services;

var builder = WebApplication.CreateBuilder(args);

// MongoDb settings
builder.Services.Configure<MongoDbSettings>(
   builder.Configuration.GetSection(nameof(MongoDbSettings)));

builder.Services.AddSingleton<EventsService>();

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
    //app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
