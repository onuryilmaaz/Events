using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace EventWithMongo.Models
{
    public class EventWithLocation
    {
        [BsonId]
        [BsonRepresentation(BsonType.ObjectId)]
        public string Id { get; set; }

        public string EventTitle { get; set; }
        public string Decs { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public string Category { get; set; }
        public Geometry Geometry { get; set; }
        public Properties Properties { get; set; }
        public string ImageUrl { get; set; } // ✅ Yeni eklenen resim alanı
    }

    public class Geometry
    {
        public string Type { get; } = "Point"; // sabit
        public double[] Coordinates { get; set; } // [longitude, latitude]
    }

    public class Properties
    {
        public string Name { get; set; }
        public string Address { get; set; }
        public string Phone { get; set; }
    }
}