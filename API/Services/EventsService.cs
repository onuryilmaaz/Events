using MongoDB.Driver;
using API.Models;
using Microsoft.Extensions.Options;
using API.Settings;

namespace API.Services
{
    public class EventsService
    {
        private readonly IMongoCollection<Events> _events;

        public EventsService(IOptions<MongoDbSettings> options)
        {
            var client = new MongoClient(options.Value.ConnectionString);
            var database = client.GetDatabase(options.Value.DatabaseName);
            _events = database.GetCollection<Events>(options.Value.CollectionName);
        }

        public async Task<List<Events>> GetAllAsync() =>
            await _events.Find(_ => true).ToListAsync();

        public async Task<Events> GetByIdAsync(string id) =>
            await _events.Find(e => e.Id == id).FirstOrDefaultAsync();

        public async Task CreateAsync(Events @event) =>
            await _events.InsertOneAsync(@event);

        public async Task UpdateAsync(string id, Events @event) =>
            await _events.ReplaceOneAsync(e => e.Id == id, @event);

        public async Task DeleteAsync(string id) =>
            await _events.DeleteOneAsync(e => e.Id == id);

        public async Task<List<Events>> GetNearbyAsync(double longitude, double latitude, double maxDistanceInMeters)
        {
            var filter = Builders<Events>.Filter.GeoWithinCenterSphere(x => x.Geometry.Coordinates, longitude, latitude, maxDistanceInMeters);
            return await _events.Find(filter).ToListAsync();
        }
    }
}