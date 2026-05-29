const mongoose = require('mongoose');

const privacySchema = new mongoose.Schema({
  phoneVisibility: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'contacts' },
  lastSeenVisibility: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'everyone' },
  profilePhotoVisibility: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'everyone' },
  forwardMessageVisibility: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'everyone' },
  addToGroups: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'contacts' },
  voiceCallPermission: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'contacts' },
  videoCallPermission: { type: String, enum: ['everyone', 'contacts', 'nobody'], default: 'contacts' },
  allowFindingByPhone: { type: Boolean, default: true },
  allowFindingByUsername: { type: Boolean, default: true },
});

const userSchema = new mongoose.Schema({
  phoneNumber: { type: String, required: true, unique: true },
  username: { type: String, unique: true, sparse: true },
  displayName: { type: String, default: 'User' },
  bio: { type: String, maxlength: 500 },
  avatar: { type: String },
  accountType: { type: String, enum: ['personal', 'business', 'bot'], default: 'personal' },
  verificationLevel: { type: String, enum: ['none', 'basic', 'verified', 'official'], default: 'none' },
  status: { type: String, enum: ['online', 'offline', 'recently', 'lastSeen'], default: 'offline' },
  lastSeen: { type: Date },
  isBot: { type: Boolean, default: false },
  isPremium: { type: Boolean, default: false },
  privacy: { type: privacySchema, default: () => ({}) },
  twoFactorEnabled: { type: Boolean, default: false },
  passcodeEnabled: { type: Boolean, default: false },
  biometricEnabled: { type: Boolean, default: false },
  blockedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  restrictionStatus: { type: String, enum: ['none', 'warning', 'limited', 'suspended', 'banned'], default: 'none' },
  strikesCount: { type: Number, default: 0 },
  otp: { type: String },
  otpExpiry: { type: Date },
  lastLogin: { type: Date },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

userSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('User', userSchema);
