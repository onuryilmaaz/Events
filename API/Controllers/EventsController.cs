using Microsoft.AspNetCore.Mvc;
using EventWithMongo.Models;
using EventWithMongo.Services;
using EventWithMongo.DTOs;

namespace EventWithMongo.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class EventsController : ControllerBase
    {
        private readonly EventsService _service;

        public EventsController(EventsService service) =>
            _service = service;

        // ✅ Tüm etkinlikleri listele
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var events = await _service.GetAllAsync();
            var responseList = events.Select(e => new EventResponseDto
            {
                Id = e.Id,
                EventTitle = e.EventTitle,
                Decs = e.Decs,
                StartDate = e.StartDate,
                EndDate = e.EndDate,
                Category = e.Category,
                Coordinates = e.Geometry.Coordinates,
                Name = e.Properties.Name,
                Address = e.Properties.Address,
                Phone = e.Properties.Phone,
                ImageUrl = e.ImageUrl
            });

            return Ok(responseList);
        }

        // ✅ ID'ye göre etkinliği getir
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(string id)
        {
            var item = await _service.GetByIdAsync(id);
            if (item == null) return NotFound();

            var response = new EventResponseDto
            {
                Id = item.Id,
                EventTitle = item.EventTitle,
                Decs = item.Decs,
                StartDate = item.StartDate,
                EndDate = item.EndDate,
                Category = item.Category,
                Coordinates = item.Geometry.Coordinates,
                Name = item.Properties.Name,
                Address = item.Properties.Address,
                Phone = item.Properties.Phone,
                ImageUrl = item.ImageUrl
            };

            return Ok(response);
        }

        // ✅ Yeni etkinlik oluştur
        [HttpPost]
        public async Task<IActionResult> Create(EventCreateDto dto)
        {
            var @event = new EventWithLocation
            {
                EventTitle = dto.EventTitle,
                Decs = dto.Decs,
                StartDate = dto.StartDate,
                EndDate = dto.EndDate,
                Category = dto.Category,
                Geometry = new Geometry
                {
                    Coordinates = dto.Coordinates
                },
                Properties = new Properties
                {
                    Name = dto.Name,
                    Address = dto.Address,
                    Phone = dto.Phone
                },
                ImageUrl = dto.ImageUrl
            };

            await _service.CreateAsync(@event);
            return CreatedAtAction(nameof(GetById), new { id = @event.Id }, new EventResponseDto
            {
                Id = @event.Id,
                EventTitle = @event.EventTitle,
                Decs = @event.Decs,
                StartDate = @event.StartDate,
                EndDate = @event.EndDate,
                Category = @event.Category,
                Coordinates = @event.Geometry.Coordinates,
                Name = @event.Properties.Name,
                Address = @event.Properties.Address,
                Phone = @event.Properties.Phone,
                ImageUrl = @event.ImageUrl
            });
        }

        // ✅ Etkinliği güncelle
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(string id, EventUpdateDto dto)
        {
            var existing = await _service.GetByIdAsync(id);
            if (existing == null) return NotFound();

            existing.EventTitle = dto.EventTitle;
            existing.Decs = dto.Decs;
            existing.StartDate = dto.StartDate;
            existing.EndDate = dto.EndDate;
            existing.Category = dto.Category;
            existing.Geometry.Coordinates = dto.Coordinates;
            existing.Properties.Name = dto.Name;
            existing.Properties.Address = dto.Address;
            existing.Properties.Phone = dto.Phone;
            existing.ImageUrl = dto.ImageUrl;

            await _service.UpdateAsync(id, existing);

            return Ok("Etkinlik güncellendi");
        }

        // ✅ Etkinliği sil
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            var existing = await _service.GetByIdAsync(id);
            if (existing == null) return NotFound();

            await _service.DeleteAsync(id);
            return Ok("Etkinlik silindi");
        }

        // ✅ Yakındaki etkinlikleri bul
        [HttpGet("nearby")]
        public async Task<IActionResult> GetNearby(
            [FromQuery] double longitude,
            [FromQuery] double latitude,
            [FromQuery] double maxDistance = 5000)
        {
            var items = await _service.GetNearbyAsync(longitude, latitude, maxDistance);

            var responseList = items.Select(e => new EventResponseDto
            {
                Id = e.Id,
                EventTitle = e.EventTitle,
                Decs = e.Decs,
                StartDate = e.StartDate,
                EndDate = e.EndDate,
                Category = e.Category,
                Coordinates = e.Geometry.Coordinates,
                Name = e.Properties.Name,
                Address = e.Properties.Address,
                Phone = e.Properties.Phone,
                ImageUrl = e.ImageUrl
            });

            return Ok(responseList);
        }
    }
}