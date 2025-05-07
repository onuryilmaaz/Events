import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({
  providedIn: 'root',
})
export class EventService {
  private apiUrl = 'http://localhost:3000/api/events'; // BACKEND URL'ine göre düzenle

  constructor(private http: HttpClient) {}

  createEvent(eventData: any) {
    return this.http.post(this.apiUrl, eventData);
  }
}
