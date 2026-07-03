export interface Velocity {
  vNorth: number;
  vEast: number;
  vUp: number;
}

export interface TemporalContext {
  timestamp: string;
  validUntil: string;
  velocity: Velocity;
}

export interface DiagnosticLogger {
  timestamp: string;
  toolName: string;
  version: string;
  command: string;
  exitCode: number;
  traceback: string;
  targetFile: string;
  snippetContent: string;
  logFailure(message: string): void;
  serializePayload(): string;
}

export interface ToolingSubsystem {
  logger: DiagnosticLogger;
}

export interface Counter32 {
  value: number;
  increment(): void;
}

export interface Counter64 {
  value: number;
  increment(): void;
}

export interface Gauge32 {
  value: number;
  setValue(val: number): void;
}

export interface Gauge64 {
  value: number;
  setValue(val: number): void;
}

export interface Timeticks {
  value: number;
  increment(): void;
}

export interface NumericMetricsSubsystem {
  c32: Counter32;
  c64: Counter64;
  g32: Gauge32;
  g64: Gauge64;
  ticks: Timeticks;
}

export interface ExecutionAgent {
  downstreamRepoUrl: string;
  activeBranch: string;
  allowUpstreamReporting: boolean;
  detectDiagnosticPayload(payload: string): boolean;
  fileUpstreamBug(title: string, body: string): Promise<boolean>;
}

export interface AgentSubsystem {
  agent: ExecutionAgent;
}

export interface TimeZone {
  offset: number;
  name: string;
}

export interface CentisecondPrecision {
  value: number;
  format(): string;
}

export interface TemporalPrecisionContext {
  tz: TimeZone;
  precision: CentisecondPrecision;
}

export interface PhysicalAddress {
  address: string;
  postalCode: string;
  state: string;
  city: string;
  countryCode: string;
}

export interface PhysicalStructuralSubsystem {
  address: PhysicalAddress;
}

export interface IngestionWorkflow {
  parseIssueBody(body: string): string;
  writeReproCase(issueId: string): string;
  runRegressionTests(reproPath: string): boolean;
  closeIssue(issueId: string): void;
}

export interface IngestionSubsystem {
  workflow: IngestionWorkflow;
}

export interface LocationType {
  identity: 'site' | 'room' | 'building';
}

export interface LocationHierarchy {
  id: string;
  name: string;
  type: LocationType;
  parent?: LocationHierarchy;
}

export interface RackLocation {
  roomName: string;
  gridRow: number;
  gridColumn: number;
}

export interface Rack {
  maxVoltage: number;
  maxAllocatedPower: number;
  heightUnits: number;
  location: RackLocation;
}

export interface ContainedChassis {
  chassisId: string;
  startSlot: number;
  slotWidth: number;
  validateSlotOverlap(other: ContainedChassis): boolean;
}

export interface ChassisContainmentSubsystem {
  chassis: ContainedChassis[];
  validateAllocation(): boolean;
}

export interface EpicMapper {
  epicId: string;
  featureId: string;
  linkageJustification: string;
  validateLinkage(): boolean;
}

export interface EpicLinkageSubsystem {
  mapper: EpicMapper;
}

export interface CoverageVerifier {
  requiredCoverage: number;
  runCoverageAudit(): boolean;
  validateProfileScoping(): boolean;
}

export interface CoverageGateSubsystem {
  verifier: CoverageVerifier;
}

export interface TraceabilityVerifier {
  enforceUmlConstraints(): boolean;
  verifyTraceabilityMatrix(): boolean;
  checkDocCompleteness(): boolean;
}

export interface TraceabilityGateSubsystem {
  verifier: TraceabilityVerifier;
}
