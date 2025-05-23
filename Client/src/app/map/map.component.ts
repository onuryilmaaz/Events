import { Component, OnInit } from '@angular/core';
import * as L from 'leaflet';
import 'leaflet-routing-machine';
import { EventService } from '../event.service';
import { CommonModule } from '@angular/common';
import { ToastrService } from 'ngx-toastr';
import {
  FormBuilder,
  FormGroup,
  Validators,
  ReactiveFormsModule,
} from '@angular/forms';

const iconRetinaUrl = '/marker.png';
const iconUrl = '/marker.png';
const shadowUrl = '/marker.png';
const iconDefault = L.icon({
  iconRetinaUrl,
  iconUrl,
  shadowUrl,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  tooltipAnchor: [16, -28],
  shadowSize: [41, 41],
});
L.Marker.prototype.options.icon = iconDefault;

@Component({
  selector: 'app-map',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  providers: [EventService],
  templateUrl: './map.component.html',
  styleUrls: ['./map.component.scss'],
})
export class MapComponent implements OnInit {
  private map!: L.Map;
  storeList: any[] = [];
  previewUrl: string | ArrayBuffer | null = null;
  showEventFormPopup = false;
  eventForm!: FormGroup;
  isLoading = false;
  isUpdateMode = false;
  currentEventId: string | null = null;
  public routeDetails: any = null;
  public myIcon = L.icon({
    iconUrl: 'marker.png',
    iconSize: [30, 40],
  });
  private currentRouteControl: L.Routing.Control | null = null;
  public routeOptions: any[] = [];
  public selectedRouteIndex: number | null = null;
  private taxiMarker: L.Marker | null = null;

  constructor(
    private eventService: EventService,
    private toastr: ToastrService,
    private fb: FormBuilder
  ) {}

  ngOnInit(): void {
    this.initForm();
    this.initMap();
    this.fetchEvents();
    this.handleMapClick();
  }

  private initForm(): void {
    this.eventForm = this.fb.group({
      eventTitle: ['', Validators.required],
      decs: ['', Validators.required],
      category: ['', Validators.required],
      startDate: ['', Validators.required],
      endDate: ['', Validators.required],
      name: ['', Validators.required],
      address: ['', Validators.required],
      phone: ['', Validators.required],
      imageFile: [null],
      lat: ['', Validators.required],
      lng: ['', Validators.required],
      imageUrl: [''],
    });
  }

  public getInstructionIconClass(
    instruction: any,
    i: number,
    routeDetails: any
  ): string {
    if (i === routeDetails.instructions.length - 1) {
      return 'bi bi-flag-fill'; // Son adım için bayrak ikonu
    }
    switch (instruction.type) {
      case 'Turn':
        switch (instruction.modifier) {
          case 'SlightRight':
          case 'SharpRight':
            return 'bi bi-arrow-up-right';
          case 'SlightLeft':
          case 'SharpLeft':
            return 'bi bi-arrow-down-right';
          case 'Right':
            return 'bi bi-arrow-right';
          case 'Left':
            return 'bi bi-arrow-left';
          case 'UturnRight':
            return 'bi bi-arrow-bar-right';
          case 'UturnLeft':
            return 'bi bi-arrow-bar-left';
          default:
            return 'bi bi-arrow-up';
        }
      case 'Continue':
        return 'bi bi-arrow-up';
      default:
        return 'bi bi-info-circle';
    }
  }

  private initMap(): void {
    this.map = L.map('map').setView(
      [40.698730617524085, 29.92057800292969],
      20
    );
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright ">OpenStreetMap</a> contributors',
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

  onImageSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      const file = input.files[0];
      this.eventForm.patchValue({
        imageFile: file,
      });
      const reader = new FileReader();
      reader.onload = () => {
        this.previewUrl = reader.result;
      };
      reader.readAsDataURL(file);
    }
  }

  closePopup(): void {
    this.showEventFormPopup = false;
    this.eventForm.reset();
    this.previewUrl = null;
    this.isUpdateMode = false;
    this.currentEventId = null;
  }

  openCreateForm(lat: number, lng: number): void {
    this.isUpdateMode = false;
    this.currentEventId = null;
    this.eventForm.reset();
    this.previewUrl = null;
    this.eventForm.patchValue({
      lat: lat.toString(),
      lng: lng.toString(),
    });
    this.showEventFormPopup = true;
  }

  openUpdateForm(event: any): void {
    this.isUpdateMode = true;
    this.currentEventId = event.id;
    this.previewUrl = event.imageUrl || null;
    this.eventForm.patchValue({
      eventTitle: event.eventTitle,
      decs: event.decs,
      category: event.category,
      startDate: this.formatDateForInput(event.startDate),
      endDate: this.formatDateForInput(event.endDate),
      name: event.name,
      address: event.address,
      phone: event.phone,
      lat: event.geometry.coordinates[1].toString(),
      lng: event.geometry.coordinates[0].toString(),
      imageUrl: event.imageUrl || '',
    });
    this.showEventFormPopup = true;
  }

  formatDateForInput(dateString: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return '';
    return date.toISOString().split('T')[0];
  }

  public fetchEvents(): void {
    this.eventService.getEvents().subscribe({
      next: (data) => {
        this.storeList = data.map((event: any) => ({
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: [event.coordinates[0], event.coordinates[1]],
          },
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
        }));
        this.addEventsToMap();
      },
      error: (err) => console.error('Veri çekme hatası:', err),
    });
  }

  public addEventsToMap(): void {
    this.map.eachLayer((layer) => {
      if (layer instanceof L.Marker) {
        this.map.removeLayer(layer);
      }
    });
    const shopsLayer = L.geoJSON(this.storeList as any, {
      pointToLayer: (feature: any, latlng: L.LatLng) =>
        L.marker(latlng, { icon: this.myIcon }),
      onEachFeature: (feature: any, layer: L.Layer) => {
        layer.bindPopup(this.makePopupContent(feature), {
          closeButton: false,
          offset: L.point(0, -8),
        });
      },
    });
    shopsLayer.addTo(this.map);
  }

  public makePopupContent(shop: any): string {
    return `
      <div class="rounded-3" style="width: 18rem;">
        <div class="position-relative">
          <img src="${
            shop.imageUrl == null ? 'noImage.jpg' : shop.imageUrl
          }" class="card-img-top" style="height: 200px; object-fit: cover;" />
          <span class="badge bg-info position-absolute top-0 end-0 m-2">${
            shop.category
          }</span>
        </div>
        <div class="card-body">
          <h5 class="card-title text-center fw-bold mb-3">${
            shop.eventTitle
          }</h5>
          <ul class="list-unstyled">
            <li class="mb-2"><i class="fa-solid fa-user text-primary me-2"></i><strong>Düzenleyen:</strong> ${
              shop.name
            }</li>
            <li class="mb-2"><i class="fas fa-align-left text-secondary me-2"></i>Açıklama: ${
              shop.decs
            }</li>
            <li class="mb-2"><i class="fas fa-map-marker-alt text-danger me-2"></i>Addres: ${
              shop.address
            }</li>
            <li class="mb-2"><i class="fa-solid fa-calendar-days text-success me-2"></i>Başlangıç: ${this.formatExpiryDate(
              shop.startDate
            )}</li>
            <li class="mb-2"><i class="fa-solid fa-calendar-days text-success me-2"></i>Bitiş: ${this.formatExpiryDate(
              shop.endDate
            )}</li>
            <li><i class="fas fa-phone-alt text-info me-2"></i>${
              shop.phone
            }</li>
          </ul>
        </div>
      </div>`;
  }

  public flyToStore(store: any): void {
    const lat = store.geometry.coordinates[1];
    const lng = store.geometry.coordinates[0];
    this.map.flyTo([lat, lng], 14, { duration: 3 });
    setTimeout(() => {
      L.popup()
        .setLatLng([lat, lng])
        .setContent(this.makePopupContent(store))
        .openOn(this.map);
    }, 3000);
  }

  public deleteEvent(eventId: number): void {
    if (confirm('Bu etkinliği silmek istediğinize emin misiniz?')) {
      this.eventService.deleteEvent(eventId.toString()).subscribe({
        next: () => {
          this.toastr.success('Etkinlik başarıyla silindi', 'Başarılı');
          this.fetchEvents();
        },
        error: (err) => {
          console.error('Etkinlik silinirken hata oluştu:', err);
          this.toastr.error(
            `Etkinlik silinemedi: ${err.error?.message || 'Bilinmeyen hata'}`,
            'Hata'
          );
        },
      });
    }
  }

  public calculateRoute(store: any): void {
    const destinationLat = store.geometry.coordinates[1];
    const destinationLng = store.geometry.coordinates[0];

    this.clearPreviousRoutes();

    this.currentRouteControl = L.Routing.control({
      waypoints: [
        L.latLng(40.702683, 29.886353),
        L.latLng(destinationLat, destinationLng),
      ],
      routeWhileDragging: false,
      showAlternatives: true,
      addWaypoints: false,
      // @ts-ignore
      draggableWaypoints: false,
      altLineOptions: {
        styles: [{ color: '#17a2b8', opacity: 0.8, weight: 4 }],
        extendToWaypoints: true,
        missingRouteTolerance: 10, // Metre cinsinden tolerans değeri
      },
    })
      .on('routesfound', (event: any) => {
        this.routeOptions = event.routes.map((route: any) => ({
          summary: {
            totalDistance: (route.summary.totalDistance / 1000).toFixed(2),
            totalTime: Math.round(route.summary.totalTime / 60),
          },
          coordinates: route.coordinates,
          instructions: route.instructions.map((inst: any) => ({
            text: inst.text,
            distance: (inst.distance / 1000).toFixed(2),
            time: Math.round(inst.time / 60),
            type: inst.type,
            modifier: inst.modifier,
            street: inst.road,
          })),
        }));
      })
      .addTo(this.map);

    if (!this.taxiMarker) {
      var taxiIcon = L.icon({
        iconUrl: '/taxi.png',
        iconSize: [110, 70],
      });
      this.taxiMarker = L.marker([40.702683, 29.886353], {
        icon: taxiIcon,
      }).addTo(this.map);
    }
  }

  public selectRoute(index: number): void {
    this.selectedRouteIndex = index;
  }

  public startSelectedRoute(): void {
    if (this.selectedRouteIndex === null || !this.taxiMarker) return;
    const route = this.routeOptions[this.selectedRouteIndex];
    let i = 0;
    const animateMarker = () => {
      if (i < route.coordinates.length) {
        const coord = route.coordinates[i];
        this.taxiMarker!.setLatLng([coord.lat, coord.lng]);
        i++;
        setTimeout(animateMarker, 50);
      }
    };
    animateMarker();
  }

  private clearPreviousRoutes(): void {
    if (this.currentRouteControl) {
      this.map.removeControl(this.currentRouteControl);
      this.currentRouteControl = null;
    }
    this.routeOptions = [];
    this.selectedRouteIndex = null;
  }

  public clearRoutes(): void {
    this.clearPreviousRoutes();
    this.clearPreviousRouteAndMarker();
  }

  public clearPreviousRouteAndMarker(): void {
    if (this.currentRouteControl) {
      this.map.removeControl(this.currentRouteControl);
      this.currentRouteControl = null;
    }
    this.map.eachLayer((layer: any) => {
      if (
        layer instanceof L.Marker &&
        layer.options.icon &&
        layer.options.icon.options.iconUrl === '/taxi.png'
      ) {
        this.map.removeLayer(layer);
        this.taxiMarker = null;
      }
    });
    this.routeDetails = null;
  }

  handleMapClick(): void {
    this.map.on('click', (e: L.LeafletMouseEvent) => {
      const lat = e.latlng.lat;
      const lng = e.latlng.lng;
      this.openCreateForm(lat, lng);
    });
  }

  onSubmit(): void {
    if (this.eventForm.invalid) {
      this.toastr.warning('Lütfen tüm gerekli alanları doldurun', 'Uyarı');
      return;
    }
    this.isLoading = true;
    const formData = new FormData();
    const formValues = this.eventForm.value;
    formData.append('EventTitle', formValues.eventTitle);
    formData.append('Decs', formValues.decs);
    formData.append('Category', formValues.category);
    formData.append('StartDate', formValues.startDate);
    formData.append('EndDate', formValues.endDate);
    formData.append('Name', formValues.name);
    formData.append('Address', formValues.address);
    formData.append('Phone', formValues.phone);
    const latValue = parseFloat(formValues.lat);
    const lngValue = parseFloat(formValues.lng);
    formData.append('Coordinates[0]', lngValue.toString());
    formData.append('Coordinates[1]', latValue.toString());
    if (formValues.imageFile) {
      formData.append('ImageFile', formValues.imageFile);
    }
    if (this.isUpdateMode && this.currentEventId) {
      this.eventService.updateEvent(this.currentEventId, formData).subscribe({
        next: () => {
          this.toastr.success('Etkinlik başarıyla güncellendi', 'Başarılı');
          this.eventForm.reset();
          this.showEventFormPopup = false;
          this.previewUrl = null;
          this.isUpdateMode = false;
          this.currentEventId = null;
          this.isLoading = false;
          this.fetchEvents();
        },
        error: (err) => {
          console.error('Etkinlik güncellenirken hata oluştu:', err);
          this.toastr.error(
            `Etkinlik güncellenemedi: ${
              err.error?.message || 'Bilinmeyen hata'
            }`,
            'Hata'
          );
          this.isLoading = false;
        },
      });
    } else {
      this.eventService.createEvent(formData).subscribe({
        next: () => {
          this.toastr.success('Etkinlik başarıyla eklendi', 'Başarılı');
          this.eventForm.reset();
          this.showEventFormPopup = false;
          this.previewUrl = null;
          this.isLoading = false;
          this.fetchEvents();
        },
        error: (err) => {
          console.error('Etkinlik eklenirken hata oluştu:', err);
          this.toastr.error(
            `Etkinlik eklenemedi: ${err.error?.message || 'Bilinmeyen hata'}`,
            'Hata'
          );
          this.isLoading = false;
        },
      });
    }
  }
}
