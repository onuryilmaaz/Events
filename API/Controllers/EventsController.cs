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
        private readonly ILogger<EventsController> _logger;

        public EventsController(EventsService service, ImageService imageService, ILogger<EventsController> logger)
        {
            _service = service;
            _imageService = imageService;
            _logger = logger;
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
            // Verilerin doğrulanması
            if (dto.StartDate >= dto.EndDate)
            {
                return BadRequest(new { message = "Başlangıç tarihi bitiş tarihinden önce olmalıdır." });
            }

            // Resim yükleme işlemi
            string imageUrl = null;
            try
            {
                imageUrl = await _imageService.UploadImageAsync(dto.ImageFile);
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = "Resim yükleme başarısız oldu", error = ex.Message });
            }

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

            try
            {
                await _service.CreateAsync(@event);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Etkinlik oluşturulamadı", error = ex.Message });
            }

            // Başarıyla oluşturulmuş etkinlik yanıtı
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
            if (string.IsNullOrWhiteSpace(id))
            {
                return BadRequest("Geçerli bir etkinlik ID'si belirtilmelidir.");
            }

            if (dto == null)
            {
                return BadRequest("Etkinlik bilgileri boş olamaz.");
            }

            try
            {
                var existing = await _service.GetByIdAsync(id);
                if (existing == null)
                {
                    return NotFound($"ID: {id} olan etkinlik bulunamadı.");
                }

                if (dto.StartDate >= dto.EndDate)
                {
                    return BadRequest("Başlangıç tarihi, bitiş tarihinden önce olmalıdır.");
                }

                existing.EventTitle = !string.IsNullOrWhiteSpace(dto.EventTitle) ? dto.EventTitle : existing.EventTitle;
                existing.Decs = !string.IsNullOrWhiteSpace(dto.Decs) ? dto.Decs : existing.Decs;
                existing.StartDate = dto.StartDate;
                existing.EndDate = dto.EndDate;
                existing.Category = !string.IsNullOrWhiteSpace(dto.Category) ? dto.Category : existing.Category;

                if (dto.Coordinates != null && dto.Coordinates.Length == 2)
                {
                    existing.Geometry.Coordinates = dto.Coordinates;
                }

                if (existing.Properties != null)
                {
                    existing.Properties.Name = !string.IsNullOrWhiteSpace(dto.Name) ? dto.Name : existing.Properties.Name;
                    existing.Properties.Address = !string.IsNullOrWhiteSpace(dto.Address) ? dto.Address : existing.Properties.Address;
                    existing.Properties.Phone = !string.IsNullOrWhiteSpace(dto.Phone) ? dto.Phone : existing.Properties.Phone;
                }
                else
                {
                    existing.Properties = new Properties
                    {
                        Name = dto.Name,
                        Address = dto.Address,
                        Phone = dto.Phone
                    };
                }

                if (dto.ImageFile != null && dto.ImageFile.Length > 0)
                {
                    if (dto.ImageFile.Length > 10 * 1024 * 1024)
                    {
                        return BadRequest("Resim dosyası 10MB'dan büyük olamaz.");
                    }

                    var allowedTypes = new[] { "image/jpeg", "image/png", "image/jpg" };
                    if (!allowedTypes.Contains(dto.ImageFile.ContentType.ToLower()))
                    {
                        return BadRequest("Sadece JPEG, JPG ve PNG formatındaki resimler kabul edilmektedir.");
                    }

                    try
                    {
                        var imageUrl = await _imageService.UploadImageAsync(dto.ImageFile);
                        existing.ImageUrl = imageUrl;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Resim yüklenirken bir hata oluştu. ID: {id}");
                        return StatusCode(500, "Resim yüklenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.");
                    }
                }

                await _service.UpdateAsync(id, existing);

                return Ok(new { success = true, message = $"Etkinlik başarıyla güncellendi. (ID: {id})" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Etkinlik güncellenirken hata oluştu. ID: {id}");
                return StatusCode(500, "Etkinlik güncellenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.");
            }
        }
        #endregion

        #region Etkinlik Sil
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                return BadRequest("Geçerli bir etkinlik ID'si belirtilmelidir.");
            }

            try
            {
                var existing = await _service.GetByIdAsync(id);
                if (existing == null)
                {
                    return NotFound($"ID: {id} olan etkinlik bulunamadı.");
                }

                await _service.DeleteAsync(id);

                return Ok(new { success = true, message = $"Etkinlik başarıyla silindi. (ID: {id})" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Etkinlik silinirken hata oluştu. ID: {id}");
                return StatusCode(500, "Etkinlik silinirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.");
            }
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
