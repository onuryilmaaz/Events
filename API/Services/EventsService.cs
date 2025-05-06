using MongoDB.Driver;
using EventWithMongo.Models;
using Microsoft.Extensions.Options;
using API.Settings;

namespace EventWithMongo.Services
{
    public class EventsService
    {
        private readonly IMongoCollection<EventWithLocation> _events;

        public EventsService(IOptions<MongoDbSettings> options)
        {
            var client = new MongoClient(options.Value.ConnectionString);
            var database = client.GetDatabase(options.Value.DatabaseName);
            _events = database.GetCollection<EventWithLocation>(options.Value.CollectionName);
        }

        public async Task<List<EventWithLocation>> GetAllAsync() =>
            await _events.Find(_ => true).ToListAsync();

        public async Task<EventWithLocation> GetByIdAsync(string id) =>
            await _events.Find(e => e.Id == id).FirstOrDefaultAsync();

        public async Task CreateAsync(EventWithLocation @event) =>
            await _events.InsertOneAsync(@event);

        public async Task UpdateAsync(string id, EventWithLocation @event) =>
            await _events.ReplaceOneAsync(e => e.Id == id, @event);

        public async Task DeleteAsync(string id) =>
            await _events.DeleteOneAsync(e => e.Id == id);

        public async Task<List<EventWithLocation>> GetNearbyAsync(double longitude, double latitude, double maxDistanceInMeters)
        {
            var filter = Builders<EventWithLocation>.Filter.GeoWithinCenterSphere(x => x.Geometry.Coordinates, longitude, latitude, maxDistanceInMeters);
            return await _events.Find(filter).ToListAsync();
        }
    }
}