namespace API.DTOs
{
    public class EventCreateDto
    {
        public string EventTitle { get; set; }
        public string Decs { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public string Category { get; set; }

        // Geometry bilgisi (iç içe)
        public double[] Coordinates { get; set; } // [longitude, latitude]

        // Properties bilgisi (iç içe)
        public string Name { get; set; }
        public string Address { get; set; }
        public string Phone { get; set; }

        public IFormFile ImageFile { get; set; }
    }
}