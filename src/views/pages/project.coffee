Milestones = require '../tables/milestones'

projects   = require '../../models/projects'
system     = require '../../models/system'
milestones = require '../../modules/github/milestones'
issues     = require '../../modules/github/issues'
mediator   = require '../../modules/mediator'

module.exports = Ractive.extend

  'name': 'views/pages/project'

  'template': require '../../templates/pages/project'

  'components': { Milestones }

  'data':
    'ready': no

  onrender: ->
    [ owner, name ] = @get 'route'

    document.title = "#{owner}/#{name}"

    # Get the associated project.
    @set 'project', project = projects.find { owner, name }

    # Should not happen...
    throw 500 unless project

    # We don't know if we have all milestones, so fetch them.
    done = do system.async

    findMilestone = (number) ->
      _.find project.milestones or [], { number }

    fetchMilestones = (cb) ->
      milestones.fetchAll project, cb

    fetchIssues = (allMilestones, cb) ->
      async.each allMilestones, (milestone, cb) ->
        # Maybe we have this milestone already?
        return cb null if findMilestone milestone.number
        # Need to fetch the issues then.
        issues.fetchAll { owner, name, 'milestone': milestone.number }, (err, obj) ->
          return cb err if err
          # Save the milestone with issues.
          project.push 'milestones', _.extend milestone, { 'issues': obj }
          cb null
      , cb

    # Run it.
    async.waterfall [
      # First get all the milestones.
      fetchMilestones,
      # Then all the issues per milestone.
      fetchIssues
    ], (err) =>
      do done
      return mediator.fire '!app/notify', {
        'text': do err.toString
        'type': 'alert'
        'system': yes
        'ttl': null
      } if err

      # Say we are ready.
      @set 'ready', yes
