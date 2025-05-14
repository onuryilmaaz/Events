// // import { Injectable } from '@angular/core';
// // import { HttpClient } from '@angular/common/http';

// // @Injectable({
// //   providedIn: 'root',
// // })
// // export class EventService {
// //   private apiUrl = 'http://localhost:5117/api'; // BACKEND URL'ine göre düzenle

// //   constructor(private http: HttpClient) {}

// //   createEvent(eventData: any) {
// //     return this.http.post(this.apiUrl, eventData);
// //   }
// // }

// import { Injectable } from '@angular/core';
// import { HttpClient } from '@angular/common/http';
// import { Observable } from 'rxjs';

// @Injectable({
//   providedIn: 'root',
// })
// export class EventService {
//   private apiUrl = 'http://localhost:5117/api/Events'; // Backend API URL'si

//   constructor(private http: HttpClient) {}

//   getEvents(): Observable<any[]> {
//     return this.http.get<any[]>(this.apiUrl);
//   }

//   createEvent(formData: FormData) {
//     return this.http.post(this.apiUrl, formData);
//   }
// }

import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class EventService {
  private apiUrl = 'http://localhost:5117/api/Events'; // Backend API URL

  constructor(private http: HttpClient) {}

  // Etkinlikleri listele
  getEvents(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrl);
  }

  // Yeni etkinlik oluştur
  createEvent(formData: FormData) {
    return this.http.post(this.apiUrl, formData);
  }

  // Etkinlik güncelle (PUT)
  updateEvent(id: string, formData: FormData) {
    return this.http.put(`${this.apiUrl}/${id}`, formData);
  }

  // Etkinlik sil (DELETE)
  deleteEvent(id: string) {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }
}
