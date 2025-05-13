import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
  name: 'formatDateRange',
})
export class FormatDateRangePipe implements PipeTransform {
  transform(dateRange: string): string {
    if (!dateRange) return '';

    const [startStr, endStr] = dateRange.split(' - ');
    const startDate = new Date(startStr);
    const endDate = new Date(endStr);

    const options: Intl.DateTimeFormatOptions = {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'Europe/Istanbul',
      hour12: false,
    };

    const formattedStart = new Intl.DateTimeFormat('tr-TR', options).format(
      startDate
    );
    const formattedEnd = new Intl.DateTimeFormat('tr-TR', options).format(
      endDate
    );

    return `${formattedStart} - ${formattedEnd}`;
  }
}
