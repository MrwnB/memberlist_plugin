import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import EmptyState from "discourse/components/empty-state";
import UserAvatar from "discourse/components/user-avatar";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";

const collator = new Intl.Collator(undefined, {
  sensitivity: "base",
  numeric: true,
});

function cleanString(value) {
  const trimmedValue = String(value || "").trim();
  return trimmedValue || null;
}

function normalizeKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[_\s-]+/g, " ");
}

function displayNameForUser(user) {
  return cleanString(user?.name) || cleanString(user?.username) || "";
}

function secondaryLabelForMember(member, groupLabel) {
  const labels = [];
  const title = cleanString(member.title);
  const primaryGroupName = cleanString(member.primary_group_name);

  if (member.owner) {
    labels.push("Group owner");
  }

  if (title) {
    labels.push(title);
  }

  if (
    primaryGroupName &&
    normalizeKey(primaryGroupName) !== normalizeKey(groupLabel)
  ) {
    labels.push(primaryGroupName);
  }

  return [...new Set(labels)].slice(0, 2).join(" / ") || null;
}

function compareMembers(leftMember, rightMember) {
  return (
    collator.compare(leftMember.displayName, rightMember.displayName) ||
    collator.compare(leftMember.username, rightMember.username)
  );
}

function compareSections(leftSection, rightSection) {
  return collator.compare(leftSection.label, rightSection.label);
}

function memberMatchesFilter(member, filterValue) {
  if (!filterValue) {
    return true;
  }

  const searchableValue = [
    member.username,
    member.name,
    member.title,
    member.primary_group_name,
  ]
    .map((value) => normalizeKey(value))
    .filter(Boolean)
    .join(" ");

  return searchableValue.includes(filterValue);
}

export default class DiscourseMemberlistPage extends Component {
  @tracked filter = "";
  @tracked isLoading = true;
  @tracked loadError = null;
  @tracked sections = [];

  constructor() {
    super(...arguments);
    this.loadMemberlist();
  }

  get normalizedFilter() {
    return normalizeKey(this.filter);
  }

  get filteredSections() {
    if (!this.normalizedFilter) {
      return this.sections;
    }

    return this.sections.reduce((visibleSections, section) => {
      const groupMatchesFilter =
        normalizeKey(section.label).includes(this.normalizedFilter) ||
        normalizeKey(section.name).includes(this.normalizedFilter);
      const visibleMembers = groupMatchesFilter
        ? section.members
        : section.members.filter((member) =>
            memberMatchesFilter(member, this.normalizedFilter)
          );

      if (!visibleMembers.length) {
        return visibleSections;
      }

      visibleSections.push({
        ...section,
        members: visibleMembers,
      });

      return visibleSections;
    }, []);
  }

  get hasVisibleSections() {
    return this.filteredSections.length > 0;
  }

  get totalVisibleMembers() {
    return this.filteredSections.reduce(
      (memberCount, section) => memberCount + section.members.length,
      0
    );
  }

  get visibleGroupCount() {
    return this.filteredSections.length;
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value;
  }

  async loadMemberlist() {
    this.isLoading = true;
    this.loadError = null;

    try {
      const response = await ajax("/memberlist-data");
      const sections = response?.sections || [];

      this.sections = sections
        .map((section) => ({
          ...section,
          key: section.id || section.name,
          members: (section.members || [])
            .map((member) => ({
              ...member,
              key: member.id || member.username,
              displayName: displayNameForUser(member),
              profileUrl: getURL(
                userPath(member.username_lower || member.username)
              ),
              secondaryLabel: secondaryLabelForMember(member, section.label),
            }))
            .sort(compareMembers),
        }))
        .sort(compareSections);
    } catch {
      this.loadError = "We couldn't load the memberlist right now.";
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <section class="discourse-memberlist-page">
      <div class="discourse-memberlist-shell">
        <header class="discourse-memberlist-hero">
          <div class="discourse-memberlist-hero-copy">
            <p class="discourse-memberlist-eyebrow">Community memberlist</p>
            <h1>Memberlist</h1>
            <p>Browse every closed group and the members inside each one.</p>
          </div>

          {{#if this.hasVisibleSections}}
            <p class="discourse-memberlist-total">
              {{this.visibleGroupCount}}
              groups /
              {{this.totalVisibleMembers}}
              members
            </p>
          {{/if}}
        </header>

        <div class="discourse-memberlist-controls">
          <div class="inline-form">
            <Input
              @value={{this.filter}}
              placeholder="Filter groups or members"
              class="filter-name no-blur"
              {{on "input" this.updateFilter}}
            />
          </div>
        </div>

        <ConditionalLoadingSpinner @condition={{this.isLoading}}>
          {{#if this.loadError}}
            <EmptyState @body={{this.loadError}} />
          {{else if this.hasVisibleSections}}
            <div class="discourse-memberlist-sections">
              {{#each this.filteredSections key="key" as |group|}}
                <section class="discourse-memberlist-section">
                  <header class="discourse-memberlist-section-header">
                    <div>
                      <h2>{{group.label}}</h2>
                      <p>{{group.members.length}} members</p>
                    </div>
                  </header>

                  <div class="discourse-memberlist-grid">
                    {{#each group.members key="key" as |member|}}
                      <article class="discourse-memberlist-card">
                        <UserAvatar
                          @user={{member}}
                          @size="large"
                          @hideTitle={{true}}
                          class="discourse-memberlist-card-avatar"
                        />

                        <div class="discourse-memberlist-card-body">
                          <a
                            href={{member.profileUrl}}
                            class="discourse-memberlist-card-name trigger-user-card"
                            data-user-card={{member.username}}
                          >
                            {{member.displayName}}
                          </a>

                          <a
                            href={{member.profileUrl}}
                            class="discourse-memberlist-card-username"
                          >
                            @{{member.username}}
                          </a>

                          {{#if member.secondaryLabel}}
                            <p class="discourse-memberlist-card-meta">
                              {{member.secondaryLabel}}
                            </p>
                          {{/if}}
                        </div>
                      </article>
                    {{/each}}
                  </div>
                </section>
              {{/each}}
            </div>
          {{else}}
            <EmptyState
              @body={{if
                this.filter
                "No closed groups or members matched your search."
                "No closed groups have been added yet."
              }}
            />
          {{/if}}
        </ConditionalLoadingSpinner>
      </div>
    </section>
  </template>
}
