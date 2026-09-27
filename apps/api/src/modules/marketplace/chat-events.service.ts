import { Injectable } from '@nestjs/common';
import { Observable, Subject } from 'rxjs';
import { filter, map } from 'rxjs/operators';

@Injectable()
export class ChatEventsService {
  private readonly bus = new Subject<{ conversationId: string; payload: unknown }>();

  emit(conversationId: string, payload: unknown) {
    this.bus.next({ conversationId, payload });
  }

  stream(conversationId: string): Observable<unknown> {
    return this.bus.pipe(
      filter((event) => event.conversationId === conversationId),
      map((event) => event.payload),
    );
  }
}
