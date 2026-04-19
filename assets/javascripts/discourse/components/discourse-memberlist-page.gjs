import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import EmptyState from "discourse/components/empty-state";
import UserAvatar from "discourse/components/user-avatar";
import icon from "discourse/helpers/d-icon";
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

function wiseOldManUrlForRsn(rsn) {
  const cleanRsn = cleanString(rsn);

  if (!cleanRsn) {
    return null;
  }

  return `https://wiseoldman.net/players/${encodeURIComponent(cleanRsn)}`;
}

function oldSchoolHiscoresUrlForRsn(rsn) {
  const cleanRsn = cleanString(rsn);

  if (!cleanRsn) {
    return null;
  }

  return `https://secure.runescape.com/m=hiscore_oldschool/hiscorepersonal.ws?${new URLSearchParams(
    {
      user1: cleanRsn,
    }
  ).toString()}`;
}

function compareMembers(leftMember, rightMember) {
  return collator.compare(leftMember.username, rightMember.username);
}

function compareSections(leftSection, rightSection) {
  return (
    (leftSection.sortOrder ?? Number.MAX_SAFE_INTEGER) -
      (rightSection.sortOrder ?? Number.MAX_SAFE_INTEGER) ||
    collator.compare(leftSection.label, rightSection.label)
  );
}

function memberMatchesFilter(member, filterValue) {
  if (!filterValue) {
    return true;
  }

  const searchableValue = [member.username, member.name, member.rsn]
    .map((value) => normalizeKey(value))
    .filter(Boolean)
    .join(" ");

  return searchableValue.includes(filterValue);
}

function rankSlugForSection(section) {
  return normalizeKey(section.name || section.label).replace(/\s+/g, "-");
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

  get primarySections() {
    return this.filteredSections.filter((section) => !section.isReserveRank);
  }

  get reserveSections() {
    return this.filteredSections.filter((section) => section.isReserveRank);
  }

  get hasPrimarySections() {
    return this.primarySections.length > 0;
  }

  get hasReserveSections() {
    return this.reserveSections.length > 0;
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
        .map((section) => {
          const isReserveRank = Boolean(
            section.isReserveRank ?? section.is_reserve_rank
          );
          const rankSlug = rankSlugForSection(section);

          return {
            ...section,
            key: section.id || section.name,
            isReserveRank,
            rankSlug,
            sectionClassName: [
              "discourse-memberlist-section",
              `discourse-memberlist-rank--${rankSlug}`,
              isReserveRank && "discourse-memberlist-section-reserve",
            ]
              .filter(Boolean)
              .join(" "),
            sortOrder: section.sort_order ?? Number.MAX_SAFE_INTEGER,
            members: (section.members || [])
              .map((member) => {
                const hasMasterGuardianGlow = Boolean(
                  member.hasMasterGuardianGlow ??
                    member.has_master_guardian_glow
                );

                return {
                  ...member,
                  key: member.id || member.username,
                  hasMasterGuardianGlow,
                  cardClassName: [
                    "discourse-memberlist-card",
                    hasMasterGuardianGlow &&
                      "discourse-memberlist-card--master-guardian",
                  ]
                    .filter(Boolean)
                    .join(" "),
                  profileUrl: getURL(
                    userPath(member.username_lower || member.username)
                  ),
                  wiseOldManUrl: wiseOldManUrlForRsn(member.rsn),
                  oldSchoolHiscoresUrl: oldSchoolHiscoresUrlForRsn(member.rsn),
                };
              })
              .sort(compareMembers),
          };
        })
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
            <p>Browse members by their primary rank and jump to profiles fast.</p>
          </div>

          {{#if this.hasVisibleSections}}
            <p class="discourse-memberlist-total">
              {{this.visibleGroupCount}}
              ranks /
              {{this.totalVisibleMembers}}
              members
            </p>
          {{/if}}
        </header>

        <div class="discourse-memberlist-controls">
          <div class="inline-form">
            <Input
              @value={{this.filter}}
              placeholder="Filter ranks, members, or RSNs"
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
              {{#if this.hasPrimarySections}}
                {{#each this.primarySections key="key" as |group|}}
                  <section class={{group.sectionClassName}}>
                    <header class="discourse-memberlist-section-header">
                      <h2>{{group.label}}</h2>
                    </header>

                    <div class="discourse-memberlist-grid">
                      {{#each group.members key="key" as |member|}}
                        <article class={{member.cardClassName}}>
                          <UserAvatar
                            @user={{member}}
                            @size="medium"
                            @hideTitle={{true}}
                            class="discourse-memberlist-card-avatar"
                          />

                          <div class="discourse-memberlist-card-body">
                            <div class="discourse-memberlist-card-identity">
                              <a
                                href={{member.profileUrl}}
                                class="discourse-memberlist-card-name trigger-user-card"
                                data-user-card={{member.username}}
                              >
                                {{member.username}}
                              </a>

                              <div class="discourse-memberlist-card-links">
                                {{#if member.wiseOldManUrl}}
                                  <a
                                    href={{member.wiseOldManUrl}}
                                    class="discourse-memberlist-card-link discourse-memberlist-card-link--wom"
                                    rel="noopener noreferrer"
                                    target="_blank"
                                    aria-label="Wise Old Man profile"
                                    title="Wise Old Man profile"
                                  >
                                    <span
                                      class="discourse-memberlist-card-link-badge"
                                      aria-hidden="true"
                                    >
                                      W
                                    </span>
                                  </a>
                                {{/if}}

                                {{#if member.oldSchoolHiscoresUrl}}
                                  <a
                                    href={{member.oldSchoolHiscoresUrl}}
                                    class="discourse-memberlist-card-link discourse-memberlist-card-link--osrs"
                                    rel="noopener noreferrer"
                                    target="_blank"
                                    aria-label="Old School RuneScape HiScores"
                                    title="Old School RuneScape HiScores"
                                  >
                                    {{icon "chart-bar"}}
                                  </a>
                                {{/if}}
                              </div>
                            </div>
                          </div>
                        </article>
                      {{/each}}
                    </div>
                  </section>
                {{/each}}
              {{/if}}

              {{#if this.hasReserveSections}}
                <section class="discourse-memberlist-reserve-block">
                  <header class="discourse-memberlist-reserve-header">
                    <h2>Reserve Ranks</h2>
                  </header>

                  <div class="discourse-memberlist-reserve-sections">
                    {{#each this.reserveSections key="key" as |group|}}
                      <section class={{group.sectionClassName}}>
                        <header class="discourse-memberlist-section-header">
                          <h2>{{group.label}}</h2>
                        </header>

                        <div class="discourse-memberlist-grid">
                          {{#each group.members key="key" as |member|}}
                            <article class={{member.cardClassName}}>
                              <UserAvatar
                                @user={{member}}
                                @size="medium"
                                @hideTitle={{true}}
                                class="discourse-memberlist-card-avatar"
                              />

                              <div class="discourse-memberlist-card-body">
                                <div class="discourse-memberlist-card-identity">
                                  <a
                                    href={{member.profileUrl}}
                                    class="discourse-memberlist-card-name trigger-user-card"
                                    data-user-card={{member.username}}
                                  >
                                    {{member.username}}
                                  </a>

                                  <div class="discourse-memberlist-card-links">
                                    {{#if member.wiseOldManUrl}}
                                      <a
                                        href={{member.wiseOldManUrl}}
                                        class="discourse-memberlist-card-link discourse-memberlist-card-link--wom"
                                        rel="noopener noreferrer"
                                        target="_blank"
                                        aria-label="Wise Old Man profile"
                                        title="Wise Old Man profile"
                                      >
                                        <span
                                          class="discourse-memberlist-card-link-badge"
                                          aria-hidden="true"
                                        >
                                          W
                                        </span>
                                      </a>
                                    {{/if}}

                                    {{#if member.oldSchoolHiscoresUrl}}
                                      <a
                                        href={{member.oldSchoolHiscoresUrl}}
                                        class="discourse-memberlist-card-link discourse-memberlist-card-link--osrs"
                                        rel="noopener noreferrer"
                                        target="_blank"
                                        aria-label="Old School RuneScape HiScores"
                                        title="Old School RuneScape HiScores"
                                      >
                                        {{icon "chart-bar"}}
                                      </a>
                                    {{/if}}
                                  </div>
                                </div>
                              </div>
                            </article>
                          {{/each}}
                        </div>
                      </section>
                    {{/each}}
                  </div>
                </section>
              {{/if}}
            </div>
          {{else}}
            <EmptyState
              @body={{if
                this.filter
                "No ranks or members matched your search."
                "No closed groups have been added yet."
              }}
            />
          {{/if}}
        </ConditionalLoadingSpinner>
      </div>
    </section>
  </template>
}
