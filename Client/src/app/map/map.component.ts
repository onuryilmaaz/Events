import { Component, OnInit } from '@angular/core';
import * as L from 'leaflet';
import { EventService } from '../event.service';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-map',
  standalone: true,
  imports: [CommonModule],
  providers: [EventService],
  templateUrl: './map.component.html',
  styleUrls: ['./map.component.scss'],
})
export class MapComponent implements OnInit {
  private map!: L.Map;
  storeList: any[] = [];

  public myIcon = L.icon({
    iconUrl: 'marker.png',
    iconSize: [30, 40],
  });

  constructor(private eventService: EventService) {}

  ngOnInit(): void {
    this.initMap();
    this.fetchEvents();
    this.handleMapClick();
  }

  private initMap(): void {
    this.map = L.map('map').setView(
      [40.698730617524085, 29.92057800292969],
      20
    );
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map);
  }

  formatExpiryDate(expiryDate: string | Date | undefined): string {
    if (!expiryDate) return 'Süre belirtilmemiş';

    const date = expiryDate instanceof Date ? expiryDate : new Date(expiryDate);

    if (isNaN(date.getTime())) {
      console.warn('Geçersiz tarih:', expiryDate);
      return 'Geçersiz tarih';
    }

    return date.toLocaleDateString('tr-TR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'UTC',
    });
  }

  previewUrl: string | ArrayBuffer | null = null;

  onImageSelected(event: Event): void {
    const input = event.target as HTMLInputElement;

    if (input.files && input.files[0]) {
      const file = input.files[0];
      const reader = new FileReader();

      reader.onload = () => {
        this.previewUrl = reader.result;
      };

      reader.readAsDataURL(file);
    }
  }

  private fetchEvents(): void {
    this.eventService.getEvents().subscribe({
      next: (data) => {
        this.storeList = data.map((event: any) => ({
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [event.coordinates[0], event.coordinates[1]],
          },
          properties: {
            id: event.id,
            category: event.category,
            eventTitle: event.eventTitle,
            name: event.name,
            decs: event.decs,
            address: event.address,
            phone: event.phone,
            startDate: event.startDate,
            endDate: event.endDate,
            imageUrl: event.imageUrl,
          },
        }));
        this.addEventsToMap();
      },
      error: (err) => console.error('Veri çekme hatası:', err),
    });
  }

  private addEventsToMap(): void {
    const shopsLayer = L.geoJSON(this.storeList as any, {
      pointToLayer: (feature: any, latlng: L.LatLng) => {
        return L.marker(latlng, { icon: this.myIcon });
      },
      onEachFeature: (feature: any, layer: L.Layer) => {
        layer.bindPopup(this.makePopupContent(feature), {
          closeButton: false,
          offset: L.point(0, -8),
        });
      },
    });
    shopsLayer.addTo(this.map);
  }

  private makePopupContent(shop: any): string {
    return `
      <div style="width: 200px;">
          <h4>${shop.properties.name}</h4>
          <p>${shop.properties.decs}</p>
          <p>${shop.properties.address}</p>
          <p>${this.formatExpiryDate(
            shop.properties.startDate
          )}  - ${this.formatExpiryDate(shop.properties.endDate)}</p>
          <img src="${
            shop.properties.imageUrl == null
              ? 'noImage.jpg'
              : shop.properties.imageUrl
          }
            " style="width: 100%; height: auto;">
          <div class="phone-number">
              <a href="tel:${shop.properties.phone}">${
      shop.properties.phone
    }</a>
          </div>
      </div>
    `;
  }

  public flyToStore(store: any): void {
    const lat = store.geometry.coordinates[1];
    const lng = store.geometry.coordinates[0];
    this.map.flyTo([lat, lng], 14, {
      duration: 3,
    });
    setTimeout(() => {
      L.popup({ closeButton: false, offset: L.point(0, -8) })
        .setLatLng([lat, lng])
        .setContent(this.makePopupContent(store))
        .openOn(this.map);
    }, 3000);
  }

  public click(shop: any): void {
    console.log('shop', shop);
    // örnek: buraya POST isteği de ekleyebilirsin
    this.eventService.createEvent(shop).subscribe({
      next: (res) => console.log('Başarıyla kaydedildi:', res),
      error: (err) => console.error('Hata oluştu:', err),
    });
  }

  private handleMapClick(): void {
    this.map.on('click', (e: L.LeafletMouseEvent) => {
      const lat = e.latlng.lat;
      const lng = e.latlng.lng;

      const formPopup = document.getElementById(
        'event-form-popup'
      ) as HTMLElement;
      const form = document.getElementById('eventForm') as HTMLFormElement;

      if (formPopup && form) {
        formPopup.style.display = 'block';

        (form.querySelector('[name="lat"]') as HTMLInputElement).value =
          lat.toString();
        (form.querySelector('[name="lng"]') as HTMLInputElement).value =
          lng.toString();
      }

      form.onsubmit = (event) => {
        event.preventDefault();

        const formData = new FormData();

        const eventForm = form as HTMLFormElement;

        formData.append(
          'EventTitle',
          (eventForm.querySelector('[name="eventTitle"]') as HTMLInputElement)
            .value
        );
        formData.append(
          'Decs',
          (eventForm.querySelector('[name="decs"]') as HTMLTextAreaElement)
            .value
        );
        formData.append(
          'Category',
          (eventForm.querySelector('[name="category"]') as HTMLSelectElement)
            .value
        );
        formData.append(
          'StartDate',
          (eventForm.querySelector('[name="startDate"]') as HTMLInputElement)
            .value
        );
        formData.append(
          'EndDate',
          (eventForm.querySelector('[name="endDate"]') as HTMLInputElement)
            .value
        );
        formData.append(
          'Name',
          (eventForm.querySelector('[name="name"]') as HTMLInputElement).value
        );
        formData.append(
          'Address',
          (eventForm.querySelector('[name="address"]') as HTMLInputElement)
            .value
        );
        formData.append(
          'Phone',
          (eventForm.querySelector('[name="phone"]') as HTMLInputElement).value
        );

        const latValue = parseFloat(
          (eventForm.querySelector('[name="lat"]') as HTMLInputElement).value
        );
        const lngValue = parseFloat(
          (eventForm.querySelector('[name="lng"]') as HTMLInputElement).value
        );
        formData.append('Coordinates[0]', lngValue.toString());
        formData.append('Coordinates[1]', latValue.toString());

        const imageInput = eventForm.querySelector(
          '[name="imageFile"]'
        ) as HTMLInputElement;
        if (imageInput?.files?.length) {
          formData.append('ImageFile', imageInput.files[0]);
        }

        this.eventService.createEvent(formData).subscribe({
          next: () => {
            alert('Etkinlik başarıyla eklendi');
            form.reset();
            formPopup.style.display = 'none';
            this.fetchEvents();
          },
          error: (err) => {
            console.error('Etkinlik eklenirken hata oluştu:', err);
            alert(
              `Etkinlik eklenemedi: ${err.error?.message || 'Bilinmeyen hata'}`
            );
          },
        });
      };
    });
  }
}
