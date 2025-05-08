// import { Injectable } from '@angular/core';
// import { HttpClient } from '@angular/common/http';

// @Injectable({
//   providedIn: 'root',
// })
// export class EventService {
//   private apiUrl = 'http://localhost:5117/api'; // BACKEND URL'ine göre düzenle

//   constructor(private http: HttpClient) {}

//   createEvent(eventData: any) {
//     return this.http.post(this.apiUrl, eventData);
//   }
// }

import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class EventService {
  private apiUrl = 'http://localhost:5117/api/Events'; // Backend API URL'si

  constructor(private http: HttpClient) {}

  // Verileri çekmek için bir fonksiyon
  getEvents(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrl); // API'den veri çekme
  }

  createEvent(formData: FormData) {
    return this.http.post(this.apiUrl, formData);
  }
}
