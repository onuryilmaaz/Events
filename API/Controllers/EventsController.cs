using Microsoft.AspNetCore.Mvc;
using API.Models;
using API.Services;
using API.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class EventsController : ControllerBase
    {
        private readonly EventsService _service;
        private readonly ImageService _imageService;

        public EventsController(EventsService service, ImageService imageService)
        {
            _service = service;
            _imageService = imageService;
        }

        #region Etkinlikleri Listele
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
        #endregion

        #region ID'ye Göre Etkinlik Getir
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
        #endregion

        #region Etkinlik Oluştur
        [HttpPost]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> Create([FromForm] EventCreateDto dto)
        {
            var imageUrl = await _imageService.UploadImageAsync(dto.ImageFile);

            var @event = new Events
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
                ImageUrl = imageUrl
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
        #endregion

        #region Etkinlik Güncelle
        [HttpPut("{id}")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> Update(string id, [FromForm] EventUpdateDto dto)
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

            if (dto.ImageFile != null)
            {
                var imageUrl = await _imageService.UploadImageAsync(dto.ImageFile);
                existing.ImageUrl = imageUrl;
            }

            await _service.UpdateAsync(id, existing);

            return Ok("Etkinlik güncellendi");
        }
        #endregion

        #region Etkinlik Sil
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            var existing = await _service.GetByIdAsync(id);
            if (existing == null) return NotFound();

            await _service.DeleteAsync(id);
            return Ok("Etkinlik silindi");
        }
        #endregion

        #region Yakındaki etkinlikleri bul
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
        #endregion
    }
}
