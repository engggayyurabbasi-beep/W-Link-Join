import {createHash} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";

initializeApp();

setGlobalOptions({maxInstances: 10});

const db = getFirestore();

const issueOptions: Record<string, string[]> = {
  "Account & Profile": [
    "Login or account access",
    "Profile details",
    "Account settings",
  ],
  "Group Submission": [
    "Cannot submit a group",
    "Submission form issue",
    "Submission limit question",
  ],
  "Group Link": [
    "Invite link is invalid",
    "Group link has expired",
    "Cannot join a group",
  ],
  "Group Listing": [
    "Wrong group information",
    "Duplicate group",
    "Report inappropriate group",
  ],
  "Saved Groups": [
    "Cannot save a group",
    "Saved group is missing",
  ],
  "App & Technical": [
    "App not opening",
    "App is slow or freezing",
    "Display or navigation issue",
  ],
  "Privacy & Safety": [
    "Report spam or scam",
    "Privacy concern",
    "Abusive or harmful content",
  ],
  "Other": [
    "Suggestion or feedback",
    "Other issue",
  ],
};

const categories = [
  "Art/Design/Photography",
  "Auto/Vehicle",
  "Business/Advertising/Marketing",
  "Comedy/Funny",
  "Dating/Flirting/Chatting",
  "Education/School",
  "Entertainment/Masti",
  "Family/Relationships",
  "Fan Club/Celebrities",
  "Fashion/Style/Clothing",
  "Film/Animation",
  "Food/Drinks",
  "Gaming/Apps",
  "Health/Beauty/Fitness",
  "Jobs/Career",
  "Money/Earning",
  "Music/Audio/Songs",
  "News/Magazines/Politics",
  "Pets/Animals/Nature",
  "Roleplay/Comics",
  "Science/Technology",
  "Shopping/Buy/Sell",
  "Social/Friendship/Community",
  "Spiritual/Devotional",
  "Sports/Games",
  "Thoughts/Quotes/Jokes",
  "Travel/Local/Place",
  "Food & Recipes",
  "Local Community",
  "Parenting & Kids",
  "Vehicles & Transport",
  "Other Communities",
];

type GroupInput = {
  id: string;
  name: string;
  currentLink: string;
  imageUrl: string;
  category: string;
  country: string;
  state: string;
  city: string;
  language: string;
  description: string;
  rules: string;
  ownerContact: string;
  showOwnerContact: boolean;
};

/**
 * Checks authentication and returns the caller UID.
 * @param {object} request Callable request containing authentication data.
 * @return {string} Authenticated user's UID.
 */
function requireAuth(request: {
  auth?: {uid: string} | undefined;
}): string {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  return uid;
}

/**
 * Validates and parses the submitted group payload.
 * @param {unknown} value Untrusted group payload.
 * @return {GroupInput} Validated group input.
 */
function getGroupInput(value: unknown): GroupInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Invalid group information.");
  }

  const data = value as Record<string, unknown>;

  const stringFields = [
    "id",
    "name",
    "currentLink",
    "imageUrl",
    "category",
    "country",
    "state",
    "city",
    "language",
    "description",
    "rules",
    "ownerContact",
  ];

  for (const field of stringFields) {
    if (typeof data[field] !== "string") {
      throw new HttpsError(
        "invalid-argument",
        `Invalid ${field} field.`,
      );
    }
  }

  if (typeof data.showOwnerContact !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "Invalid contact visibility setting.",
    );
  }

  return data as unknown as GroupInput;
}

/**
 * Validates and normalizes a WhatsApp invite link.
 * @param {string} value Submitted WhatsApp invite link.
 * @return {string} Normalized invite link.
 */
function normalizeWhatsAppLink(value: string): string {
  const match = value.trim().match(
    /^https:\/\/chat\.whatsapp\.com\/([A-Za-z0-9_-]+)\/?$/,
  );

  if (!match) {
    throw new HttpsError(
      "invalid-argument",
      "Only WhatsApp Group Invite Links are allowed.",
    );
  }

  return `https://chat.whatsapp.com/${match[1]}`;
}

/**
 * Creates a deterministic document ID for an invite link.
 * @param {string} link Normalized WhatsApp invite link.
 * @return {string} SHA-256 document ID.
 */
function linkDocumentId(link: string): string {
  return createHash("sha256").update(link).digest("hex");
}

/**
 * Returns the current calendar month in India.
 * @return {string} Month key in YYYY-MM format.
 */
function indiaMonthKey(): string {
  const indiaTime = new Date(Date.now() + 330 * 60 * 1000);
  const year = indiaTime.getUTCFullYear();
  const month = String(indiaTime.getUTCMonth() + 1).padStart(2, "0");

  return `${year}-${month}`;
}

/**
 * Validates group fields before they reach Firestore.
 * @param {GroupInput} group Submitted group data.
 * @param {string} uid Authenticated owner UID.
 * @return {Object} Validated group data.
 */
function validateGroup(
  group: GroupInput,
  uid: string,
): GroupInput & {currentLink: string} {
  const clean = {
    ...group,
    id: group.id.trim(),
    name: group.name.trim(),
    currentLink: normalizeWhatsAppLink(group.currentLink),
    imageUrl: group.imageUrl.trim(),
    category: group.category.trim(),
    country: group.country.trim(),
    state: group.state.trim(),
    city: group.city.trim(),
    language: group.language.trim(),
    description: group.description.trim(),
    rules: "",
    ownerContact: group.showOwnerContact ?
      group.ownerContact.trim() : "",
  };

  if (!/^[A-Za-z0-9_-]{1,80}$/.test(clean.id)) {
    throw new HttpsError("invalid-argument", "Invalid group ID.");
  }

  if (clean.name.length === 0 || clean.name.length > 20) {
    throw new HttpsError(
      "invalid-argument",
      "Group name must contain 1 to 20 characters.",
    );
  }

  if (!categories.includes(clean.category)) {
    throw new HttpsError("invalid-argument", "Invalid group category.");
  }

  const wordCount = clean.description.length === 0 ?
    0 : clean.description.split(/\s+/).length;

  if (wordCount < 1 || wordCount > 50) {
    throw new HttpsError(
      "invalid-argument",
      "Description must contain 1 to 50 words.",
    );
  }

  if (
    clean.imageUrl !== "" &&
    !new RegExp(
      "^https://firebasestorage\\.googleapis\\.com/v0/b/" +
      "w-link-join\\.firebasestorage\\.app/o/group_images%2F" +
      uid.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") +
      "%2F" + clean.id +
      "%2Fimage\\?alt=media&token=.+$",
    ).test(clean.imageUrl)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid group image URL.",
    );
  }

  return clean;
}

/**
 * Creates the standard duplicate invite-link error.
 * @return {HttpsError} Duplicate-link error.
 */
function duplicateLinkError(): HttpsError {
  return new HttpsError(
    "already-exists",
    "This WhatsApp group has already been added. " +
    "Please submit a different group link.",
  );
}

/**
 * Checks the link registry and existing group documents.
 * @param {FirebaseFirestore.Transaction} transaction Firestore transaction.
 * @param {string} link Normalized invite link.
 * @param {string} groupId Current group ID.
 * @return {Promise<void>} Resolves when the link is available.
 */
async function checkDuplicateLink(
  transaction: FirebaseFirestore.Transaction,
  link: string,
  groupId: string,
): Promise<void> {
  const linkRef = db.collection("groupLinks").doc(linkDocumentId(link));

  const currentQuery = db.collection("groups")
    .where("currentLink", "==", link).limit(1);

  const currentSlashQuery = db.collection("groups")
    .where("currentLink", "==", `${link}/`).limit(1);

  const previousQuery = db.collection("groups")
    .where("previousLink", "==", link).limit(1);

  const previousSlashQuery = db.collection("groups")
    .where("previousLink", "==", `${link}/`).limit(1);

  const [linkSnapshot, current, currentSlash, previous, previousSlash] =
    await Promise.all([
      transaction.get(linkRef),
      transaction.get(currentQuery),
      transaction.get(currentSlashQuery),
      transaction.get(previousQuery),
      transaction.get(previousSlashQuery),
    ]);

  if (
    linkSnapshot.exists &&
    linkSnapshot.data()?.groupId !== groupId
  ) {
    throw duplicateLinkError();
  }

  for (const snapshot of [
    current,
    currentSlash,
    previous,
    previousSlash,
  ]) {
    if (snapshot.docs.some((doc) => doc.id !== groupId)) {
      throw duplicateLinkError();
    }
  }
}

/**
 * Builds the Firestore document fields for a group.
 * @param {Object} group Validated group data.
 * @param {string} uid Owner UID.
 * @param {string} previousLink Previous invite link.
 * @param {boolean} isNew Whether this is a new group.
 * @return {Record<string, unknown>} Firestore group document data.
 */
function groupDocumentData(
  group: GroupInput & {currentLink: string},
  uid: string,
  previousLink: string,
  isNew: boolean,
): Record<string, unknown> {
  const now = FieldValue.serverTimestamp();

  return {
    id: group.id,
    name: group.name,
    currentLink: group.currentLink,
    previousLink,
    imageUrl: group.imageUrl,
    category: group.category,
    subcategory: "",
    country: group.country,
    state: group.state,
    city: group.city,
    language: group.language,
    description: group.description,
    rules: group.rules,
    ownerContact: group.ownerContact,
    showOwnerContact: group.showOwnerContact,
    ownerUid: uid,
    approvalStatus: "pending",
    verificationStatus: isNew ? "pending" : undefined,
    viewCount: isNew ? 0 : undefined,
    joinClickCount: isNew ? 0 : undefined,
    createdAt: isNew ? now : undefined,
    updatedAt: now,
  };
}

export const createSupportTicket = onCall(
  {region: "asia-south2"},
  async (request) => {
    const uid = requireAuth(request);
    const category = request.data?.category;
    const issue = request.data?.issue;
    const message = request.data?.message;

    if (
      typeof category !== "string" ||
      !Object.prototype.hasOwnProperty.call(issueOptions, category)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Please select a valid issue category.",
      );
    }

    if (
      typeof issue !== "string" ||
      !issueOptions[category].includes(issue)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Please select a valid issue type.",
      );
    }

    if (
      typeof message !== "string" ||
      message.trim().length === 0 ||
      message.trim().length > 3000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Your message must contain 1 to 3000 characters.",
      );
    }

    const ticketRef = db.collection("supportTickets").doc();

    await ticketRef.set({
      uid,
      category,
      issue,
      message: message.trim(),
      status: "open",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {success: true, ticketId: ticketRef.id};
  },
);

export const submitGroup = onCall(
  {region: "asia-south2"},
  async (request) => {
    const uid = requireAuth(request);
    const group = validateGroup(getGroupInput(request.data?.group), uid);
    const groupRef = db.collection("groups").doc(group.id);
    const quotaRef = db.collection("userQuotas").doc(uid);
    const linkRef = db.collection("groupLinks").doc(
      linkDocumentId(group.currentLink),
    );
    const monthKey = indiaMonthKey();

    await db.runTransaction(async (transaction) => {
      const [groupSnapshot, quotaSnapshot] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(quotaRef),
      ]);

      if (groupSnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "This group ID already exists.",
        );
      }

      const quotaData = quotaSnapshot.data();
      const used = quotaData?.monthKey === monthKey ?
        Number(quotaData?.submissionCount ?? 0) : 0;

      if (used >= 2) {
        throw new HttpsError(
          "resource-exhausted",
          "Free Plan limit reached. You can submit 2 groups per month.",
        );
      }

      await checkDuplicateLink(transaction, group.currentLink, group.id);

      transaction.create(groupRef, {
        ...groupDocumentData(group, uid, "", true),
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.set(linkRef, {
        groupId: group.id,
        ownerUid: uid,
        link: group.currentLink,
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.set(quotaRef, {
        monthKey,
        submissionCount: used + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {success: true, groupId: group.id};
  },
);

export const updateGroup = onCall(
  {region: "asia-south2"},
  async (request) => {
    const uid = requireAuth(request);
    const group = validateGroup(getGroupInput(request.data?.group), uid);
    const groupRef = db.collection("groups").doc(group.id);

    await db.runTransaction(async (transaction) => {
      const groupSnapshot = await transaction.get(groupRef);

      if (!groupSnapshot.exists) {
        throw new HttpsError("not-found", "Group not found.");
      }

      const existing = groupSnapshot.data()!;

      if (existing.ownerUid !== uid) {
        throw new HttpsError(
          "permission-denied",
          "You are not allowed to edit this group.",
        );
      }

      const oldLink = normalizeWhatsAppLink(
        String(existing.currentLink ?? ""),
      );
      const oldPrevious = existing.previousLink ?
        normalizeWhatsAppLink(String(existing.previousLink)) : "";

      const editableFields = [
        "name",
        "currentLink",
        "imageUrl",
        "category",
        "country",
        "state",
        "city",
        "language",
        "description",
        "rules",
        "ownerContact",
        "showOwnerContact",
      ] as const;

      const changed = editableFields.some((field) =>
        group[field] !== (
          field === "currentLink" ? oldLink : existing[field]
        ),
      );

      if (!changed) {
        return;
      }

      const linkChanged = group.currentLink !== oldLink;

      if (linkChanged) {
        await checkDuplicateLink(transaction, group.currentLink, group.id);
      }

      const newPrevious = linkChanged ? oldLink : oldPrevious;

      const updateData: Record<string, unknown> = {
        name: group.name,
        currentLink: group.currentLink,
        previousLink: newPrevious,
        imageUrl: group.imageUrl,
        category: group.category,
        country: group.country,
        state: group.state,
        city: group.city,
        language: group.language,
        description: group.description,
        rules: group.rules,
        ownerContact: group.ownerContact,
        showOwnerContact: group.showOwnerContact,
        approvalStatus: "pending",
        verificationStatus: "pending",
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (linkChanged) {
        const newLinkRef = db.collection("groupLinks").doc(
          linkDocumentId(group.currentLink),
        );

        const oldLinkRef = db.collection("groupLinks").doc(
          linkDocumentId(oldLink),
        );

        transaction.set(newLinkRef, {
          groupId: group.id,
          ownerUid: uid,
          link: group.currentLink,
          createdAt: FieldValue.serverTimestamp(),
        });

        transaction.set(oldLinkRef, {
          groupId: group.id,
          ownerUid: uid,
          link: oldLink,
          createdAt: FieldValue.serverTimestamp(),
        });

        if (
          oldPrevious &&
          oldPrevious !== oldLink &&
          oldPrevious !== group.currentLink
        ) {
          const previousRef = db.collection("groupLinks").doc(
            linkDocumentId(oldPrevious),
          );
          transaction.delete(previousRef);
        }
      }

      transaction.update(groupRef, updateData);
    });

    return {success: true, groupId: group.id};
  },
);

/**
 * Verifies that the caller has the Super Admin custom claims.
 * @param {object} request Callable request.
 * @return {string} Authenticated admin UID.
 */
function requireSuperAdmin(request: {
  auth?: {
    uid: string;
    token: Record<string, unknown>;
  };
}): string {
  const uid = request.auth?.uid;
  const token = request.auth?.token;

  if (!uid || token?.admin !== true || token?.role !== "super_admin") {
    throw new HttpsError("permission-denied", "Super Admin access required.");
  }

  return uid;
}

/**
 * Lists pending groups for the Super Admin.
 */
export const listPendingGroups = onCall(
  {region: "asia-south2"},
  async (request) => {
    requireSuperAdmin(request);
    const limit = Math.min(
      Math.max(Number(request.data?.limit) || 30, 1),
      100,
    );

    const snapshot = await db.collection("groups")
      .where("approvalStatus", "==", "pending")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    return {
      groups: snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  },
);

/**
 * Approves or rejects a group.
 */
export const moderateGroup = onCall(
  {region: "asia-south2"},
  async (request) => {
    const adminUid = requireSuperAdmin(request);
    const groupId = request.data?.groupId;
    const decision = request.data?.decision;
    const reason = request.data?.reason;

    if (
      typeof groupId !== "string" ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(groupId)
    ) {
      throw new HttpsError("invalid-argument", "Invalid group ID.");
    }

    if (decision !== "approve" && decision !== "reject") {
      throw new HttpsError("invalid-argument", "Invalid moderation decision.");
    }

    if (
      reason !== undefined &&
      (typeof reason !== "string" || reason.trim().length > 1000)
    ) {
      throw new HttpsError("invalid-argument", "Invalid rejection reason.");
    }

    const groupRef = db.collection("groups").doc(groupId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(groupRef);

      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Group not found.");
      }

      if (snapshot.data()?.approvalStatus !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "Only pending groups can be moderated.",
        );
      }

      transaction.update(groupRef, {
        approvalStatus: decision === "approve" ? "approved" : "rejected",
        verificationStatus: decision === "approve" ? "verified" : "rejected",
        moderationReason: decision === "reject" ? (reason?.trim() || "") : "",
        moderatedBy: adminUid,
        moderatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {success: true, groupId, decision};
  },
);

/**
 * Lists support tickets for the Super Admin.
 */
export const listSupportTickets = onCall(
  {region: "asia-south2"},
  async (request) => {
    requireSuperAdmin(request);
    const limit = Math.min(
      Math.max(Number(request.data?.limit) || 30, 1),
      100,
    );
    const status = request.data?.status;

    let query = db.collection("supportTickets")
      .orderBy("createdAt", "desc")
      .limit(limit);

    if (
      status === "open" ||
      status === "in_progress" ||
      status === "resolved"
    ) {
      query = db.collection("supportTickets")
        .where("status", "==", status)
        .orderBy("createdAt", "desc")
        .limit(limit);
    }

    const snapshot = await query.get();

    return {
      tickets: snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  },
);

/**
 * Replies to a support ticket and updates its status.
 */
export const replySupportTicket = onCall(
  {region: "asia-south2"},
  async (request) => {
    const adminUid = requireSuperAdmin(request);
    const ticketId = request.data?.ticketId;
    const reply = request.data?.reply;
    const status = request.data?.status ?? "resolved";

    if (typeof ticketId !== "string" || ticketId.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Invalid ticket ID.");
    }

    if (
      typeof reply !== "string" ||
      reply.trim().length === 0 ||
      reply.trim().length > 3000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Reply must contain 1 to 3000 characters.",
      );
    }

    if (status !== "resolved" && status !== "in_progress") {
      throw new HttpsError("invalid-argument", "Invalid ticket status.");
    }

    const ticketRef = db.collection("supportTickets").doc(ticketId.trim());
    const ticketSnapshot = await ticketRef.get();

    if (!ticketSnapshot.exists) {
      throw new HttpsError("not-found", "Support ticket not found.");
    }

    await ticketRef.update({
      adminReply: reply.trim(),
      status,
      repliedBy: adminUid,
      repliedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {success: true, ticketId};
  },
);

/**
 * Allows a group owner to request deletion.
 */
export const requestGroupDeletion = onCall(
  {region: "asia-south2"},
  async (request) => {
    const uid = requireAuth(request);
    const groupId = request.data?.groupId;

    if (
      typeof groupId !== "string" ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(groupId)
    ) {
      throw new HttpsError("invalid-argument", "Invalid group ID.");
    }

    const groupRef = db.collection("groups").doc(groupId);
    const deletionRef = db.collection("groupDeletionRequests").doc(groupId);

    await db.runTransaction(async (transaction) => {
      const [groupSnapshot, deletionSnapshot] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(deletionRef),
      ]);

      if (!groupSnapshot.exists) {
        throw new HttpsError("not-found", "Group not found.");
      }

      if (groupSnapshot.data()?.ownerUid !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Only the group owner can request deletion.",
        );
      }

      if (deletionSnapshot.data()?.status === "pending") {
        throw new HttpsError(
          "already-exists",
          "A deletion request is already pending.",
        );
      }

      transaction.set(deletionRef, {
        groupId,
        ownerUid: uid,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {success: true, groupId};
  },
);

/**
 * Lists group deletion requests for the Super Admin.
 */
export const listGroupDeletionRequests = onCall(
  {region: "asia-south2"},
  async (request) => {
    requireSuperAdmin(request);
    const limit = Math.min(
      Math.max(Number(request.data?.limit) || 30, 1),
      100,
    );

    const snapshot = await db.collection("groupDeletionRequests")
      .where("status", "==", "pending")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    return {
      requests: snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  },
);

/**
 * Approves or rejects a group deletion request.
 */
export const reviewGroupDeletion = onCall(
  {region: "asia-south2"},
  async (request) => {
    const adminUid = requireSuperAdmin(request);
    const groupId = request.data?.groupId;
    const decision = request.data?.decision;
    const reason = request.data?.reason;

    if (
      typeof groupId !== "string" ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(groupId)
    ) {
      throw new HttpsError("invalid-argument", "Invalid group ID.");
    }

    if (decision !== "approve" && decision !== "reject") {
      throw new HttpsError("invalid-argument", "Invalid deletion decision.");
    }

    if (
      reason !== undefined &&
      (typeof reason !== "string" || reason.trim().length > 1000)
    ) {
      throw new HttpsError("invalid-argument", "Invalid review reason.");
    }

    const groupRef = db.collection("groups").doc(groupId);
    const deletionRef = db.collection("groupDeletionRequests").doc(groupId);

    await db.runTransaction(async (transaction) => {
      const [groupSnapshot, deletionSnapshot] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(deletionRef),
      ]);

      if (!groupSnapshot.exists || !deletionSnapshot.exists) {
        throw new HttpsError(
          "not-found", "Group or deletion request not found.",
        );
      }

      const group = groupSnapshot.data()!;
      const deletion = deletionSnapshot.data()!;

      if (deletion.status !== "pending") {
        throw new HttpsError(
          "failed-precondition",
          "This deletion request has already been reviewed.",
        );
      }

      if (deletion.ownerUid !== group.ownerUid) {
        throw new HttpsError(
          "failed-precondition",
          "Deletion request owner does not match the group owner.",
        );
      }

      if (decision === "reject") {
        transaction.update(deletionRef, {
          status: "rejected",
          reviewReason: reason?.trim() || "",
          reviewedBy: adminUid,
          reviewedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      const currentLink = normalizeWhatsAppLink(
        String(group.currentLink ?? ""),
      );
      const previousLink = group.previousLink ?
        normalizeWhatsAppLink(String(group.previousLink)) : "";

      const currentLinkRef = db.collection("groupLinks")
        .doc(linkDocumentId(currentLink));
      const previousLinkRef = previousLink ?
        db.collection("groupLinks").doc(linkDocumentId(previousLink)) : null;

      const currentLinkSnapshot = await transaction.get(currentLinkRef);
      const previousLinkSnapshot = previousLinkRef ?
        await transaction.get(previousLinkRef) : null;

      transaction.delete(groupRef);

      if (
        currentLinkSnapshot.exists &&
        currentLinkSnapshot.data()?.groupId === groupId
      ) {
        transaction.delete(currentLinkRef);
      }

      if (
        previousLinkRef &&
        previousLinkSnapshot?.exists &&
        previousLinkSnapshot.data()?.groupId === groupId
      ) {
        transaction.delete(previousLinkRef);
      }

      transaction.update(deletionRef, {
        status: "approved",
        reviewReason: reason?.trim() || "",
        reviewedBy: adminUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {success: true, groupId, decision};
  },
);
