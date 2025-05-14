// import { Component, OnInit } from '@angular/core';
// import * as L from 'leaflet';
// import { EventService } from '../event.service';
// import { CommonModule } from '@angular/common';
// import { ToastrService } from 'ngx-toastr';

// @Component({
//   selector: 'app-map',
//   standalone: true,
//   imports: [CommonModule],
//   providers: [EventService],
//   templateUrl: './map.component.html',
//   styleUrls: ['./map.component.scss'],
// })
// export class MapComponent implements OnInit {
//   private map!: L.Map;
//   storeList: any[] = [];

//   public myIcon = L.icon({
//     iconUrl: 'marker.png',
//     iconSize: [30, 40],
//   });

//   constructor(
//     private eventService: EventService,
//     private toastr: ToastrService
//   ) {}

//   ngOnInit(): void {
//     this.initMap();
//     this.fetchEvents();
//     this.handleMapClick();
//   }

//   private initMap(): void {
//     this.map = L.map('map').setView(
//       [40.698730617524085, 29.92057800292969],
//       20
//     );
//     L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
//       attribution:
//         '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
//     }).addTo(this.map);
//   }

//   formatExpiryDate(expiryDate: string | Date | undefined): string {
//     if (!expiryDate) return 'Süre belirtilmemiş';

//     const date = expiryDate instanceof Date ? expiryDate : new Date(expiryDate);

//     if (isNaN(date.getTime())) {
//       console.warn('Geçersiz tarih:', expiryDate);
//       return 'Geçersiz tarih';
//     }

//     return date.toLocaleDateString('tr-TR', {
//       year: 'numeric',
//       month: 'long',
//       day: 'numeric',
//       hour: '2-digit',
//       minute: '2-digit',
//       timeZone: 'UTC',
//     });
//   }

//   previewUrl: string | ArrayBuffer | null = null;

//   onImageSelected(event: Event): void {
//     const input = event.target as HTMLInputElement;

//     if (input.files && input.files[0]) {
//       const file = input.files[0];
//       const reader = new FileReader();

//       reader.onload = () => {
//         this.previewUrl = reader.result;
//       };

//       reader.readAsDataURL(file);
//     }
//   }

//   private fetchEvents(): void {
//     this.eventService.getEvents().subscribe({
//       next: (data) => {
//         this.storeList = data.map((event: any) => ({
//           type: 'Feature',
//           geometry: {
//             type: 'Point',
//             coordinates: [event.coordinates[0], event.coordinates[1]],
//           },
//           id: event.id,
//           category: event.category,
//           eventTitle: event.eventTitle,
//           name: event.name,
//           decs: event.decs,
//           address: event.address,
//           phone: event.phone,
//           startDate: event.startDate,
//           endDate: event.endDate,
//           imageUrl: event.imageUrl,
//         }));
//         this.addEventsToMap();
//       },
//       error: (err) => console.error('Veri çekme hatası:', err),
//     });
//   }

//   private addEventsToMap(): void {
//     const shopsLayer = L.geoJSON(this.storeList as any, {
//       pointToLayer: (feature: any, latlng: L.LatLng) => {
//         return L.marker(latlng, { icon: this.myIcon });
//       },
//       onEachFeature: (feature: any, layer: L.Layer) => {
//         layer.bindPopup(this.makePopupContent(feature), {
//           closeButton: false,
//           offset: L.point(0, -8),
//         });
//       },
//     });
//     shopsLayer.addTo(this.map);
//   }

//   private makePopupContent(shop: any): string {
//     return `
//         <div class="rounded-3" style="width: 18rem;">
//           <div class="position-relative">
//             <img
//               src="${shop.imageUrl == null ? 'noImage.jpg' : shop.imageUrl}"
//               class="card-img-top"
//               style="height: 200px; object-fit: cover; border-top-left-radius: 1rem; border-top-right-radius: 1rem;"
//             />
//             <span
//               class="badge bg-info position-absolute top-0 end-0 m-2 px-3 py-2 fs-6 rounded-pill shadow">
//                 ${shop.category}
//             </span>
//           </div>
//           <div class="card-body">
//             <h5 class="card-title text-center fw-bold mb-3">Deneme Başlığı</h5>
//             <ul class="list-unstyled">
//               <li class="mb-2">
//                 <i class="fa-solid fa-user text-primary me-2"></i>
//                 <strong>Düzenleyen:</strong> ${shop.name}
//               </li>
//               <li class="mb-2">
//                 <i class="fas fa-align-left text-secondary me-2"></i>
//                 Açıklama: ${shop.decs}
//               </li>
//               <li class="mb-2">
//                 <i class="fas fa-map-marker-alt text-danger me-2"></i>
//                 Addres: ${shop.address}
//               </li>
//               <li class="mb-2">
//               <i class="fa-solid fa-calendar-days text-success me-2"></i>
//                Başlangıç Tarihi:
//                   ${this.formatExpiryDate(shop.startDate)}
//               </li>
//               <li class="mb-2">
//               <i class="fa-solid fa-calendar-days text-success me-2"></i>
//                Bitiş Tarihi:
//                   ${this.formatExpiryDate(shop.endDate)}
//               </li>
//               <li>
//                 <i class="fas fa-phone-alt text-info me-2"></i>
//                 ${shop.phone}
//               </li>
//             </ul>
//           </div>
//         </div>
//     `;
//   }

//   public flyToStore(store: any): void {
//     const lat = store.geometry.coordinates[1];
//     const lng = store.geometry.coordinates[0];
//     this.map.flyTo([lat, lng], 14, {
//       duration: 3,
//     });
//     setTimeout(() => {
//       L.popup({ closeButton: false, offset: L.point(0, -8) })
//         .setLatLng([lat, lng])
//         .setContent(this.makePopupContent(store))
//         .openOn(this.map);
//     }, 3000);
//   }

//   public click(shop: any): void {
//     console.log('shop', shop);

//     this.eventService.createEvent(shop).subscribe({
//       next: (res) => {
//         console.log('Başarıyla kaydedildi:', res);
//         this.toastr.success('Etkinlik başarıyla kaydedildi!', 'Başarılı');
//       },
//       error: (err) => {
//         console.error('Hata oluştu:', err);
//         this.toastr.error('Etkinlik kaydedilemedi.', 'Hata');
//       },
//     });
//   }

//   private handleMapClick(): void {
//     this.map.on('click', (e: L.LeafletMouseEvent) => {
//       const lat = e.latlng.lat;
//       const lng = e.latlng.lng;

//       const formPopup = document.getElementById(
//         'event-form-popup'
//       ) as HTMLElement;
//       const form = document.getElementById('eventForm') as HTMLFormElement;

//       if (formPopup && form) {
//         formPopup.style.display = 'block';

//         (form.querySelector('[name="lat"]') as HTMLInputElement).value =
//           lat.toString();
//         (form.querySelector('[name="lng"]') as HTMLInputElement).value =
//           lng.toString();
//       }

//       form.onsubmit = (event) => {
//         event.preventDefault();

//         const formData = new FormData();

//         const eventForm = form as HTMLFormElement;

//         formData.append(
//           'EventTitle',
//           (eventForm.querySelector('[name="eventTitle"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'Decs',
//           (eventForm.querySelector('[name="decs"]') as HTMLTextAreaElement)
//             .value
//         );
//         formData.append(
//           'Category',
//           (eventForm.querySelector('[name="category"]') as HTMLSelectElement)
//             .value
//         );
//         formData.append(
//           'StartDate',
//           (eventForm.querySelector('[name="startDate"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'EndDate',
//           (eventForm.querySelector('[name="endDate"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'Name',
//           (eventForm.querySelector('[name="name"]') as HTMLInputElement).value
//         );
//         formData.append(
//           'Address',
//           (eventForm.querySelector('[name="address"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'Phone',
//           (eventForm.querySelector('[name="phone"]') as HTMLInputElement).value
//         );

//         const latValue = parseFloat(
//           (eventForm.querySelector('[name="lat"]') as HTMLInputElement).value
//         );
//         const lngValue = parseFloat(
//           (eventForm.querySelector('[name="lng"]') as HTMLInputElement).value
//         );
//         formData.append('Coordinates[0]', lngValue.toString());
//         formData.append('Coordinates[1]', latValue.toString());

//         const imageInput = eventForm.querySelector(
//           '[name="imageFile"]'
//         ) as HTMLInputElement;
//         if (imageInput?.files?.length) {
//           formData.append('ImageFile', imageInput.files[0]);
//         }

//         this.eventService.createEvent(formData).subscribe({
//           next: () => {
//             this.toastr.success('Etkinlik başarıyla eklendi', 'Başarılı');
//             form.reset();
//             formPopup.style.display = 'none';
//             this.fetchEvents();
//           },
//           error: (err) => {
//             console.error('Etkinlik eklenirken hata oluştu:', err);
//             this.toastr.error(
//               `Etkinlik eklenemedi: ${err.error?.message || 'Bilinmeyen hata'}`,
//               'Hata'
//             );
//           },
//         });
//       };
//     });
//   }
// }

// import { Component, OnInit } from '@angular/core';
// import * as L from 'leaflet';
// import { EventService } from '../event.service';
// import { CommonModule } from '@angular/common';
// import { ToastrService } from 'ngx-toastr';

// @Component({
//   selector: 'app-map',
//   standalone: true,
//   imports: [CommonModule],
//   providers: [EventService],
//   templateUrl: './map.component.html',
//   styleUrls: ['./map.component.scss'],
// })
// export class MapComponent implements OnInit {
//   private map!: L.Map;
//   storeList: any[] = [];

//   public myIcon = L.icon({
//     iconUrl: 'marker.png',
//     iconSize: [30, 40],
//   });

//   constructor(
//     private eventService: EventService,
//     private toastr: ToastrService
//   ) {}

//   ngOnInit(): void {
//     this.initMap();
//     this.fetchEvents();
//     this.handleMapClick();

//     document.addEventListener('edit-event', (e: any) => {
//       const id = e.detail;
//       const eventToEdit = this.storeList.find((ev) => ev.id === id);

//       if (eventToEdit) {
//         this.updateEvent(id, {
//           eventTitle: 'Güncellenmiş Başlık',
//           decs: 'Yeni açıklama',
//           category: eventToEdit.category,
//           startDate: eventToEdit.startDate,
//           endDate: eventToEdit.endDate,
//           name: eventToEdit.name,
//           address: eventToEdit.address,
//           phone: eventToEdit.phone,
//           coordinates: eventToEdit.geometry.coordinates,
//         });
//       }
//     });

//     document.addEventListener('delete-event', (e: any) => {
//       const id = e.detail;
//       this.deleteEvent(id);
//     });
//   }

//   private initMap(): void {
//     this.map = L.map('map').setView(
//       [40.698730617524085, 29.92057800292969],
//       20
//     );
//     L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
//       attribution:
//         '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
//     }).addTo(this.map);
//   }

//   formatExpiryDate(expiryDate: string | Date | undefined): string {
//     if (!expiryDate) return 'Süre belirtilmemiş';
//     const date = expiryDate instanceof Date ? expiryDate : new Date(expiryDate);
//     if (isNaN(date.getTime())) return 'Geçersiz tarih';
//     return date.toLocaleDateString('tr-TR', {
//       year: 'numeric',
//       month: 'long',
//       day: 'numeric',
//       hour: '2-digit',
//       minute: '2-digit',
//       timeZone: 'UTC',
//     });
//   }

//   public flyToStore(store: any): void {
//     const lat = store.geometry.coordinates[1];
//     const lng = store.geometry.coordinates[0];
//     this.map.flyTo([lat, lng], 14, {
//       duration: 3,
//     });
//     setTimeout(() => {
//       L.popup({ closeButton: false, offset: L.point(0, -8) })
//         .setLatLng([lat, lng])
//         .setContent(this.makePopupContent(store))
//         .openOn(this.map);
//     }, 3000);
//   }

//   previewUrl: string | ArrayBuffer | null = null;

//   onImageSelected(event: Event): void {
//     const input = event.target as HTMLInputElement;
//     if (input.files && input.files[0]) {
//       const file = input.files[0];
//       const reader = new FileReader();
//       reader.onload = () => {
//         this.previewUrl = reader.result;
//       };
//       reader.readAsDataURL(file);
//     }
//   }

//   private fetchEvents(): void {
//     this.eventService.getEvents().subscribe({
//       next: (data) => {
//         this.storeList = data.map((event: any) => ({
//           type: 'Feature',
//           geometry: {
//             type: 'Point',
//             coordinates: [event.coordinates[0], event.coordinates[1]],
//           },
//           id: event.id,
//           category: event.category,
//           eventTitle: event.eventTitle,
//           name: event.name,
//           decs: event.decs,
//           address: event.address,
//           phone: event.phone,
//           startDate: event.startDate,
//           endDate: event.endDate,
//           imageUrl: event.imageUrl,
//         }));
//         this.addEventsToMap();
//       },
//       error: (err) => console.error('Veri çekme hatası:', err),
//     });
//   }

//   private addEventsToMap(): void {
//     const shopsLayer = L.geoJSON(this.storeList as any, {
//       pointToLayer: (feature: any, latlng: L.LatLng) => {
//         return L.marker(latlng, { icon: this.myIcon });
//       },
//       onEachFeature: (feature: any, layer: L.Layer) => {
//         layer.bindPopup(this.makePopupContent(feature), {
//           closeButton: false,
//           offset: L.point(0, -8),
//         });
//       },
//     });
//     shopsLayer.addTo(this.map);
//   }

//   private makePopupContent(shop: any): string {
//     return `
//       <div class="rounded-3" style="width: 18rem;">
//         <div class="position-relative">
//           <img src="${
//             shop.imageUrl == null ? 'noImage.jpg' : shop.imageUrl
//           }" class="card-img-top" style="height: 200px; object-fit: cover; border-top-left-radius: 1rem; border-top-right-radius: 1rem;" />
//           <span class="badge bg-info position-absolute top-0 end-0 m-2 px-3 py-2 fs-6 rounded-pill shadow">
//             ${shop.category}
//           </span>
//         </div>
//         <div class="card-body">
//           <h5 class="card-title text-center fw-bold mb-3">${
//             shop.eventTitle
//           }</h5>
//           <ul class="list-unstyled">
//             <li class="mb-2"><i class="fa-solid fa-user text-primary me-2"></i><strong>Düzenleyen:</strong> ${
//               shop.name
//             }</li>
//             <li class="mb-2"><i class="fas fa-align-left text-secondary me-2"></i>Açıklama: ${
//               shop.decs
//             }</li>
//             <li class="mb-2"><i class="fas fa-map-marker-alt text-danger me-2"></i>Addres: ${
//               shop.address
//             }</li>
//             <li class="mb-2"><i class="fa-solid fa-calendar-days text-success me-2"></i>Başlangıç Tarihi: ${this.formatExpiryDate(
//               shop.startDate
//             )}</li>
//             <li class="mb-2"><i class="fa-solid fa-calendar-days text-success me-2"></i>Bitiş Tarihi: ${this.formatExpiryDate(
//               shop.endDate
//             )}</li>
//             <li><i class="fas fa-phone-alt text-info me-2"></i>${
//               shop.phone
//             }</li>
//           </ul>
//           <div class="text-center mt-2">
//             <button onclick="document.dispatchEvent(new CustomEvent('edit-event', { detail: '${
//               shop.id
//             }' }))" class="btn btn-warning btn-sm me-2">Güncelle</button>
//             <button onclick="document.dispatchEvent(new CustomEvent('delete-event', { detail: '${
//               shop.id
//             }' }))" class="btn btn-danger btn-sm">Sil</button>
//           </div>
//         </div>
//       </div>
//     `;
//   }

//   public updateEvent(
//     eventId: string,
//     updatedData: any,
//     imageFile?: File
//   ): void {
//     const formData = new FormData();
//     formData.append('EventTitle', updatedData.eventTitle);
//     formData.append('Decs', updatedData.decs);
//     formData.append('Category', updatedData.category);
//     formData.append('StartDate', updatedData.startDate);
//     formData.append('EndDate', updatedData.endDate);
//     formData.append('Name', updatedData.name);
//     formData.append('Address', updatedData.address);
//     formData.append('Phone', updatedData.phone);
//     formData.append('Coordinates[0]', updatedData.coordinates[0]);
//     formData.append('Coordinates[1]', updatedData.coordinates[1]);
//     if (imageFile) {
//       formData.append('ImageFile', imageFile);
//     }
//     this.eventService.updateEvent(eventId, formData).subscribe({
//       next: () => {
//         this.toastr.success('Etkinlik başarıyla güncellendi!', 'Başarılı');
//         this.fetchEvents();
//       },
//       error: (err) => {
//         console.error('Güncelleme hatası:', err);
//         this.toastr.error('Etkinlik güncellenemedi.', 'Hata');
//       },
//     });
//   }

//   public deleteEvent(eventId: string): void {
//     if (!confirm('Bu etkinliği silmek istediğinizden emin misiniz?')) return;
//     this.eventService.deleteEvent(eventId).subscribe({
//       next: () => {
//         this.toastr.success('Etkinlik başarıyla silindi!', 'Başarılı');
//         this.fetchEvents();
//       },
//       error: (err) => {
//         console.error('Silme hatası:', err);
//         this.toastr.error('Etkinlik silinemedi.', 'Hata');
//       },
//     });
//   }

//   private handleMapClick(): void {
//     this.map.on('click', (e: L.LeafletMouseEvent) => {
//       const lat = e.latlng.lat;
//       const lng = e.latlng.lng;
//       const formPopup = document.getElementById(
//         'event-form-popup'
//       ) as HTMLElement;
//       const form = document.getElementById('eventForm') as HTMLFormElement;

//       if (formPopup && form) {
//         formPopup.style.display = 'block';
//         (form.querySelector('[name="lat"]') as HTMLInputElement).value =
//           lat.toString();
//         (form.querySelector('[name="lng"]') as HTMLInputElement).value =
//           lng.toString();
//       }

//       form.onsubmit = (event) => {
//         event.preventDefault();
//         const formData = new FormData();
//         const eventForm = form as HTMLFormElement;

//         formData.append(
//           'EventTitle',
//           (eventForm.querySelector('[name="eventTitle"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'Decs',
//           (eventForm.querySelector('[name="decs"]') as HTMLTextAreaElement)
//             .value
//         );
//         formData.append(
//           'Category',
//           (eventForm.querySelector('[name="category"]') as HTMLSelectElement)
//             .value
//         );
//         formData.append(
//           'StartDate',
//           (eventForm.querySelector('[name="startDate"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'EndDate',
//           (eventForm.querySelector('[name="endDate"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'Name',
//           (eventForm.querySelector('[name="name"]') as HTMLInputElement).value
//         );
//         formData.append(
//           'Address',
//           (eventForm.querySelector('[name="address"]') as HTMLInputElement)
//             .value
//         );
//         formData.append(
//           'Phone',
//           (eventForm.querySelector('[name="phone"]') as HTMLInputElement).value
//         );

//         const latValue = parseFloat(
//           (eventForm.querySelector('[name="lat"]') as HTMLInputElement).value
//         );
//         const lngValue = parseFloat(
//           (eventForm.querySelector('[name="lng"]') as HTMLInputElement).value
//         );
//         formData.append('Coordinates[0]', lngValue.toString());
//         formData.append('Coordinates[1]', latValue.toString());

//         const imageInput = eventForm.querySelector(
//           '[name="imageFile"]'
//         ) as HTMLInputElement;
//         if (imageInput?.files?.length) {
//           formData.append('ImageFile', imageInput.files[0]);
//         }

//         this.eventService.createEvent(formData).subscribe({
//           next: () => {
//             this.toastr.success('Etkinlik başarıyla eklendi', 'Başarılı');
//             form.reset();
//             formPopup.style.display = 'none';
//             this.fetchEvents();
//           },
//           error: (err) => {
//             console.error('Etkinlik eklenirken hata oluştu:', err);
//             this.toastr.error(
//               `Etkinlik eklenemedi: ${err.error?.message || 'Bilinmeyen hata'}`,
//               'Hata'
//             );
//           },
//         });
//       };
//     });
//   }
// }

import { Component, OnInit } from '@angular/core';
import * as L from 'leaflet';
import { EventService } from '../event.service';
import { CommonModule } from '@angular/common';
import { ToastrService } from 'ngx-toastr';

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
  previewUrl: string | ArrayBuffer | null = null;
  updatingEventId: string | null = null;

  public myIcon = L.icon({
    iconUrl: 'marker.png',
    iconSize: [30, 40],
  });

  constructor(
    private eventService: EventService,
    private toastr: ToastrService
  ) {}

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
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(this.map);
  }

  formatExpiryDate(expiryDate: string | Date | undefined): string {
    if (!expiryDate) return 'Süre belirtilmemiş';
    const date = expiryDate instanceof Date ? expiryDate : new Date(expiryDate);
    if (isNaN(date.getTime())) return 'Geçersiz tarih';
    return date.toLocaleDateString('tr-TR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'UTC',
    });
  }

  onImageSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      const reader = new FileReader();
      reader.onload = () => (this.previewUrl = reader.result);
      reader.readAsDataURL(input.files[0]);
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
          id: event.id,
          ...event,
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
      <div style="width: 18rem;">
        <div>
          <img src="${
            shop.imageUrl || 'noImage.jpg'
          }" style="width:100%; height: 200px; object-fit:cover;" />
        </div>
        <div>
          <h5>${shop.eventTitle}</h5>
          <p>${shop.decs}</p>
          <p>${this.formatExpiryDate(shop.startDate)} - ${this.formatExpiryDate(
      shop.endDate
    )}</p>
        </div>
      </div>
    `;
  }

  public flyToStore(store: any): void {
    const lat = store.geometry.coordinates[1];
    const lng = store.geometry.coordinates[0];
    this.map.flyTo([lat, lng], 14);
    setTimeout(() => {
      L.popup({ closeButton: false, offset: L.point(0, -8) })
        .setLatLng([lat, lng])
        .setContent(this.makePopupContent(store))
        .openOn(this.map);
    }, 1000);
  }

  deleteEvent(id: string): void {
    this.eventService.deleteEvent(id).subscribe({
      next: () => {
        // Success handling
        this.toastr.success('Etkinlik başarıyla silindi', 'Başarılı');

        // Refresh the events list
        this.fetchEvents();
      },
      error: (err) => {
        // Error handling
        console.error('Hata oluştu:', err);
        this.toastr.error('Etkinlik silinemedi.', 'Hata');
      },
    });
  }

  public updateEvent(store: any): void {
    const formPopup = document.getElementById(
      'event-form-popup'
    ) as HTMLElement;
    const form = document.getElementById('eventForm') as HTMLFormElement;
    if (!formPopup || !form) return;

    formPopup.style.display = 'block';
    this.updatingEventId = store.id;

    (form.querySelector('[name="eventTitle"]') as HTMLInputElement).value =
      store.eventTitle;
    (form.querySelector('[name="decs"]') as HTMLTextAreaElement).value =
      store.decs;
    (form.querySelector('[name="category"]') as HTMLInputElement).value =
      store.category;
    (form.querySelector('[name="startDate"]') as HTMLInputElement).value =
      store.startDate.split('T')[0];
    (form.querySelector('[name="endDate"]') as HTMLInputElement).value =
      store.endDate.split('T')[0];
    (form.querySelector('[name="name"]') as HTMLInputElement).value =
      store.name;
    (form.querySelector('[name="address"]') as HTMLInputElement).value =
      store.address;
    (form.querySelector('[name="phone"]') as HTMLInputElement).value =
      store.phone;
    (form.querySelector('[name="lat"]') as HTMLInputElement).value =
      store.geometry.coordinates[1];
    (form.querySelector('[name="lng"]') as HTMLInputElement).value =
      store.geometry.coordinates[0];
  }

  private handleMapClick(): void {
    this.map.on('click', (e: L.LeafletMouseEvent) => {
      const lat = e.latlng.lat;
      const lng = e.latlng.lng;

      const formPopup = document.getElementById(
        'event-form-popup'
      ) as HTMLElement;
      const form = document.getElementById('eventForm') as HTMLFormElement;

      if (!formPopup || !form) return;

      formPopup.style.display = 'block';
      (form.querySelector('[name="lat"]') as HTMLInputElement).value =
        lat.toString();
      (form.querySelector('[name="lng"]') as HTMLInputElement).value =
        lng.toString();

      form.onsubmit = (event) => {
        event.preventDefault();
        const formData = new FormData(form);

        const latInput = form.querySelector('[name="lat"]') as HTMLInputElement;
        const lngInput = form.querySelector('[name="lng"]') as HTMLInputElement;

        const lat = latInput.value;
        const lng = lngInput.value;

        formData.append('Coordinates[0]', lng);
        formData.append('Coordinates[1]', lat);

        const imageInput = form.querySelector(
          '[name="imageFile"]'
        ) as HTMLInputElement;
        if (imageInput?.files?.length) {
          formData.append('ImageFile', imageInput.files[0]);
        }

        if (this.updatingEventId) {
          this.eventService
            .updateEvent(this.updatingEventId, formData)
            .subscribe({
              next: () => {
                this.toastr.success('Etkinlik güncellendi', 'Başarılı');
                form.reset();
                formPopup.style.display = 'none';
                this.updatingEventId = null;
                this.fetchEvents();
              },
              error: () => {
                this.toastr.error('Güncelleme başarısız', 'Hata');
              },
            });
        } else {
          this.eventService.createEvent(formData).subscribe({
            next: () => {
              this.toastr.success('Etkinlik eklendi', 'Başarılı');
              form.reset();
              formPopup.style.display = 'none';
              this.fetchEvents();
            },
            error: () => {
              this.toastr.error('Etkinlik eklenemedi', 'Hata');
            },
          });
        }
      };
    });
  }
}
