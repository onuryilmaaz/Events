import { Component, OnInit } from '@angular/core';
import * as L from 'leaflet';
import { EventService } from '../event.service';

@Component({
  selector: 'app-map',
  templateUrl: './map.component.html',
  styleUrls: ['./map.component.css'],
})
export class MapComponent implements OnInit {
  private map!: L.Map;

  constructor(private eventService: EventService) {}

  ngOnInit(): void {
    this.initMap();
    this.handleMapClick();
  }

  private initMap(): void {
    this.map = L.map('map').setView([41.015137, 28.97953], 6); // İstanbul başlangıç
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map);
  }

  private handleMapClick(): void {
    this.map.on('click', (e: L.LeafletMouseEvent) => {
      const lat = e.latlng.lat;
      const lng = e.latlng.lng;

      const newEvent = {
        eventTitle: 'Yeni Etkinlik',
        decs: 'Bu kullanıcı tarafından haritada seçildi',
        startDate: new Date().toISOString(),
        endDate: new Date(
          new Date().getTime() + 2 * 60 * 60 * 1000
        ).toISOString(), // 2 saat sonrası
        category: 'Diğer',
        coordinates: [lat, lng],
        name: 'Etkinlik',
        address: 'Tıklanan Konum',
        phone: '+905555555555',
        imageUrl: 'https://via.placeholder.com/150',
      };

      this.eventService.createEvent(newEvent).subscribe({
        next: () => alert('Etkinlik başarıyla kaydedildi!'),
        error: (err) => console.error('Kayıt hatası:', err),
      });
    });
  }
}
