import {
  TemporalContext,
  Velocity,
  PhysicalAddress,
  LocationType,
  LocationHierarchy,
  Rack,
  RackLocation,
  ContainedChassis,
  ChassisContainmentSubsystem
} from '../types';

/**
 * Validates a TemporalContext.
 * Property coverage: timestamp, validUntil, velocity
 */
export function validateTemporalContext(context: TemporalContext): boolean {
  if (!context.timestamp || !context.validUntil) {
    return false;
  }
  const ts = Date.parse(context.timestamp);
  const vu = Date.parse(context.validUntil);
  if (isNaN(ts) || isNaN(vu)) {
    return false;
  }
  // Temporal Validity: validUntil cannot be prior to timestamp
  return vu >= ts;
}

/**
 * Validates a PhysicalAddress.
 * Property coverage: address, postalCode, state, city, countryCode
 */
export function validatePhysicalAddress(addr: PhysicalAddress): boolean {
  if (!addr.countryCode) {
    return false;
  }
  // Country Code Validation: countryCode must match /^[A-Z]{2}$/ regex
  const countryRegex = /^[A-Z]{2}$/;
  return countryRegex.test(addr.countryCode);
}

/**
 * Validates a LocationType.
 * Property coverage: identity
 */
export function validateLocationType(locType: LocationType): boolean {
  // Location Identity Validation: LocationType must match 'site', 'room', or 'building'
  const validIdentities = ['site', 'room', 'building'];
  return validIdentities.includes(locType.identity);
}

/**
 * Validates a Rack.
 * Property coverage: maxVoltage, maxAllocatedPower, heightUnits, location
 */
export function validateRack(rack: Rack): boolean {
  // Rack Validation: maxVoltage and maxAllocatedPower must be non-negative
  if (rack.maxVoltage < 0 || rack.maxAllocatedPower < 0) {
    return false;
  }
  if (rack.heightUnits < 0) {
    return false;
  }
  return true;
}

/**
 * Validates slot overlap between two ContainedChassis instances.
 * Property coverage: chassisId, startSlot, slotWidth
 */
export function hasSlotOverlap(chassis1: ContainedChassis, chassis2: ContainedChassis): boolean {
  return (
    chassis1.startSlot < chassis2.startSlot + chassis2.slotWidth &&
    chassis2.startSlot < chassis1.startSlot + chassis1.slotWidth
  );
}

/**
 * Validates slot allocations for a ChassisContainmentSubsystem to ensure no overlaps.
 * Property coverage: chassis, validateAllocation, validateSlotOverlap
 */
export function validateChassisAllocation(subsystem: ChassisContainmentSubsystem): boolean {
  const list = subsystem.chassis;
  for (let i = 0; i < list.length; i++) {
    for (let j = i + 1; j < list.length; j++) {
      if (hasSlotOverlap(list[i], list[j])) {
        return false;
      }
    }
  }
  return true;
}
