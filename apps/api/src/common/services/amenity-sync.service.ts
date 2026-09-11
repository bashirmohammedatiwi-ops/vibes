import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Keeps the legacy amenities JSON column and the relational
 * PropertyAmenity rows in sync during the migration window:
 * rows are canonical, the JSON stays as a display-only mirror
 * for older clients (mobile app).
 */
@Injectable()
export class AmenitySyncService {
  constructor(private readonly prisma: PrismaService) {}

  private slugifyName(name: string) {
    return `am-${Buffer.from(name, 'utf8').toString('hex').slice(0, 40)}`;
  }

  /** Find-or-create amenities by their Arabic display name (legacy JSON path). */
  async resolveIdsFromNames(names: string[]) {
    const ids: string[] = [];
    for (const rawName of names) {
      const name = rawName.trim();
      if (!name) continue;
      const existing = await this.prisma.amenity.findFirst({ where: { nameAr: name } });
      if (existing) {
        ids.push(existing.id);
        continue;
      }
      const created = await this.prisma.amenity.create({
        data: {
          nameAr: name,
          slug: this.slugifyName(name),
          appliesTo: [],
        },
      });
      ids.push(created.id);
    }
    return ids;
  }

  private async namesForIds(ids: string[]) {
    if (!ids.length) return [];
    const amenities = await this.prisma.amenity.findMany({
      where: { id: { in: ids } },
    });
    const byId = new Map(amenities.map((a) => [a.id, a.nameAr]));
    return ids.map((id) => byId.get(id)).filter((name): name is string => !!name);
  }

  /**
   * Replaces a property's amenity links and mirrors display names into the
   * legacy JSON column. Returns the JSON array written.
   */
  async replacePropertyAmenities(
    propertyId: string,
    amenityIds: string[],
    tx?: Prisma.TransactionClient,
  ) {
    const client = tx ?? this.prisma;
    const uniqueIds = Array.from(new Set(amenityIds));
    const names = await this.namesForIds(uniqueIds);

    await client.propertyAmenity.deleteMany({ where: { propertyId } });
    if (uniqueIds.length) {
      await client.propertyAmenity.createMany({
        data: uniqueIds.map((amenityId, index) => ({
          propertyId,
          amenityId,
          sortOrder: index,
        })),
        skipDuplicates: true,
      });
    }
    await client.property.update({
      where: { id: propertyId },
      data: { amenities: names },
    });
    return names;
  }

  /** Sync path for legacy clients that still send the JSON string array. */
  async replaceFromLegacyNames(
    propertyId: string,
    names: string[],
    tx?: Prisma.TransactionClient,
  ) {
    const ids = await this.resolveIdsFromNames(names);
    return this.replacePropertyAmenities(propertyId, ids, tx);
  }
}
